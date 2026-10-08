#!/usr/bin/env python3
"""Release check: run the Release build through its UI tests on every supported iOS version.

Run by the prepare-release-ios skill before anything is tagged or pushed, never by CI:

    python3 -I scripts/release-check/release_check.py --version 5.22.3

For each supported iOS major (the deployment target up to the SDK, minus SKIPPED_MAJORS) it runs four
scenarios with the BookPlayerUITests target, on two simulators ("BP Release Check iOS <major>" for the
first three, "… Upgrade" for the last, so neither is reset right after playing audio):

  fresh     empty install: the Library tab shows and the app stays up
  import    test files in Documents → Import sheet → Done → "Library" → book and folder rows
  playback  tap the book → player → the elapsed time moves
  upgrade   the previous release imports and plays the same files, then this build is installed over
            it: the rows and the book's progress survive and it still plays

Every step also fails on a new crash report from the app. A failure WITH a crash report fails the check
at once. A failure without one gets one retry on a freshly reset simulator: the check fails only if it
fails again, and a scenario that passes the second time is reported as "passed on retry" with the first
failure, so nothing is hidden.

The previous release's app is cached in ~/Library/Caches/BookPlayerReleaseCheck/<version>/ (with the
fetched Swift packages in SourcePackages/); when it's missing, the previous tag is built once. A passing
run caches this build under --version for the next release.

Exit code 0 = passed; 1 = a check failed; 2 = the check couldn't run (setup problem).
The report is written to <out>/report.md (and report.json).
"""

import argparse
import datetime
import json
import math
import plistlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import traceback
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PROJECT = REPO / "BookPlayer.xcodeproj"
SCHEME = "ReleaseCheck"
TEST_CLASS = "BookPlayerUITests/ReleaseCheckUITests"
CACHE = Path.home() / "Library/Caches/BookPlayerReleaseCheck"
PACKAGES = CACHE / "SourcePackages"
SIMULATOR_PREFIX = "BP Release Check iOS"
PREFERRED_IPHONES = ["iPhone 17 Pro", "iPhone 18 Pro", "iPhone 17", "iPhone 16 Pro"]

# Time limits. XCTest stops a test that runs past its allowance; the process watchdog is the backstop.
TEST_ALLOWANCE = 180
TEST_TIMEOUT = 300
SIMCTL_TIMEOUT = 120
BOOT_TIMEOUT = 300

# iOS majors that are supported but can't be tested; each entry says why. Delete an entry once the
# deployment target moves past it.
SKIPPED_MAJORS = {
    18: "no iOS 18 simulator runtime is available for Xcode 27 (decided 2026-10-08)",
}

# Must match ReleaseCheckUITests.bookPath / .folderPath
BOOK_NAME = "Release Check Book.m4a"
FOLDER_NAME = "Release Check Folder"


class SetupError(Exception):
    """The check couldn't run; nothing was tested."""


def log(message):
    print(f"[release-check] {message}", flush=True)


def run(cmd, timeout=None, **kwargs):
    return subprocess.run(cmd, check=True, text=True, capture_output=True, timeout=timeout, **kwargs).stdout


# MARK: - Inputs


def deployment_target_major():
    settings = run(["xcodebuild", "-project", str(PROJECT), "-target", "BookPlayer", "-configuration", "Release",
                    "-showBuildSettings"])
    match = re.search(r"^\s*IPHONEOS_DEPLOYMENT_TARGET = (\d+)", settings, re.M)
    if not match:
        raise SetupError("couldn't read IPHONEOS_DEPLOYMENT_TARGET")
    return int(match.group(1))


def sdk_major():
    return int(run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).split(".")[0])


def supported_majors(minimum, newest):
    # iOS jumped from 18 to 26; there are no 19–25
    return [major for major in range(minimum, newest + 1) if not 19 <= major <= 25]


def runtime_for(major, runtimes):
    """The newest available runtime of `major` that runs a regular iPhone, and the iPhone to use."""
    candidates = []
    for runtime in runtimes:
        if runtime["platform"] != "iOS" or not runtime["isAvailable"]:
            continue
        if int(runtime["version"].split(".")[0]) != major:
            continue
        iphones = {d["name"]: d["identifier"] for d in runtime.get("supportedDeviceTypes", [])
                   if d.get("productFamily") == "iPhone"}
        device = next((iphones[name] for name in PREFERRED_IPHONES if name in iphones), None)
        if device:
            candidates.append((runtime, device))
    candidates.sort(key=lambda c: [int(x) for x in c[0]["version"].split(".")])
    return candidates[-1] if candidates else None


def previous_tag():
    """The latest release tag reachable from HEAD that isn't on HEAD itself.

    Normally HEAD isn't tagged (the skill checks before the version bump). When the check is run by hand on a
    released commit, HEAD's own tag is the release being checked, so the upgrade starts from the one before it.
    """
    cmd = ["git", "-C", str(REPO), "describe", "--tags", "--abbrev=0", "--match", "[0-9]*"]
    for own_tag in run(["git", "-C", str(REPO), "tag", "--points-at", "HEAD"]).split():
        cmd += ["--exclude", own_tag]
    try:
        return run(cmd + ["HEAD"]).strip()
    except subprocess.CalledProcessError:
        raise SetupError("no earlier release tag reachable from HEAD; pass --previous")


# MARK: - Building


def build(source, derived_data):
    log(f"building {source.name} (Release, simulator)…")
    PACKAGES.mkdir(parents=True, exist_ok=True)
    cmd = ["xcodebuild", "-project", str(source / "BookPlayer.xcodeproj"), "-configuration", "Release",
           "-destination", "generic/platform=iOS Simulator", "-derivedDataPath", str(derived_data),
           # Shared between runs so the Swift packages aren't fetched again every time
           "-clonedSourcePackagesDirPath", str(PACKAGES),
           "-skipPackagePluginValidation", "-skipMacroValidation"]
    has_scheme = (source / "BookPlayer.xcodeproj/xcshareddata/xcschemes" / f"{SCHEME}.xcscheme").exists()
    cmd += ["-scheme", SCHEME, "build-for-testing"] if has_scheme else ["-scheme", "BookPlayer", "build"]
    build_log = derived_data.parent / f"build-{source.name}.log"
    with open(build_log, "w") as out:
        if subprocess.run(cmd, stdout=out, stderr=subprocess.STDOUT).returncode != 0:
            errors = [line for line in build_log.read_text().splitlines() if "error:" in line][:5]
            raise SetupError(f"build of {source.name} failed (see {build_log}):\n" + "\n".join(errors))
    return derived_data / "Build/Products"


def ensure_debug_xcconfig(source):
    """Builds need BuildConfiguration/Debug.xcconfig to exist; a fresh checkout gets the template (never overwrite)."""
    config = source / "BuildConfiguration/Debug.xcconfig"
    if not config.exists():
        shutil.copy(source / "BuildConfiguration/Debug.template.xcconfig", config)


def git(*args):
    return run(["git", "-C", str(REPO), *args]).strip()


def only_version_bump(old, new):
    """True when `new` is `old` plus nothing but MARKETING_VERSION changes (the skill's `set app version` commit)."""
    if old == new:
        return True
    if subprocess.run(["git", "-C", str(REPO), "merge-base", "--is-ancestor", old, new]).returncode != 0:
        return False
    if git("diff", "--name-only", old, new).splitlines() != ["BookPlayer.xcodeproj/project.pbxproj"]:
        return False
    changed = [line for line in git("diff", "-U0", old, new).splitlines()
               if line[:1] in "+-" and not line.startswith(("+++", "---"))]
    return all("MARKETING_VERSION = " in line for line in changed)


def cache_app(app, version, commit, dirty):
    """Copies `app` into the cache for `version`, recording where it came from; written last, so a copy that
    stopped partway is never trusted."""
    entry = CACHE / version
    shutil.rmtree(entry, ignore_errors=True)
    entry.mkdir(parents=True)
    partial = entry / "BookPlayer.app.partial"
    shutil.copytree(app, partial, symlinks=True)
    partial.rename(entry / "BookPlayer.app")
    (entry / "source.json").write_text(json.dumps({"commit": commit, "dirty": dirty}))


def cached_app(tag):
    """The cached app for `tag`, or None (with the reason logged) when it can't be trusted as that release."""
    entry = CACHE / tag
    app, source = entry / "BookPlayer.app", entry / "source.json"
    if not entry.exists():
        return None
    try:
        recorded = json.loads(source.read_text())
    except (OSError, ValueError):
        log(f"previous release {tag}: cache has no source record (incomplete copy?), rebuilding")
        return None
    if not (app / "Info.plist").exists():
        log(f"previous release {tag}: cached app is incomplete, rebuilding")
        return None
    if recorded.get("dirty"):
        log(f"previous release {tag}: cached build had uncommitted changes, rebuilding")
        return None
    if not only_version_bump(recorded.get("commit", ""), git("rev-parse", f"{tag}^{{commit}}")):
        log(f"previous release {tag}: cached build ({recorded.get('commit', '?')[:8]}) isn't what {tag} tagged, rebuilding")
        return None
    return app


def previous_app(tag, work):
    app = cached_app(tag)
    if app:
        log(f"previous release {tag}: cached")
        return app
    log(f"previous release {tag}: building the tag once…")
    worktree = work / f"wt-{tag}"
    git("worktree", "add", "--detach", str(worktree), tag)
    try:
        ensure_debug_xcconfig(worktree)
        products = build(worktree, work / f"dd-{tag}")
        cache_app(products / "Release-iphonesimulator/BookPlayer.app", tag, git("rev-parse", f"{tag}^{{commit}}"),
                  dirty=False)
    finally:
        git("worktree", "remove", "--force", str(worktree))
        shutil.rmtree(work / f"dd-{tag}", ignore_errors=True)
    return CACHE / tag / "BookPlayer.app"


def retarget(xctestrun, app, name):
    """A copy of the .xctestrun whose UI tests install and drive another BookPlayer.app."""
    with open(xctestrun, "rb") as f:
        plist = plistlib.load(f)
    target = plist["BookPlayerUITests"]
    original = target["UITargetAppPath"]
    target["UITargetAppPath"] = str(app)
    target["DependentProductPaths"] = [str(app) if p == original else p for p in target["DependentProductPaths"]]
    copy = xctestrun.parent / name  # __TESTROOT__ is the file's folder, so it stays next to the original
    with open(copy, "wb") as f:
        plistlib.dump(plist, f)
    return copy


# MARK: - Test files


def make_fixtures(folder):
    """A 60 s book and a two-file folder of near-silent tone, so playback is real but inaudible."""
    def tone(path, seconds, rate=22050):
        wav = path.with_suffix(".wav")
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(b"".join(struct.pack("<h", int(32 * math.sin(2 * math.pi * 440 * i / rate)))
                                   for i in range(seconds * rate)))
        run(["afconvert", "-f", "m4af", "-d", "aac", str(wav), str(path)])
        wav.unlink()

    shutil.rmtree(folder, ignore_errors=True)  # a rerun with the same --out
    (folder / FOLDER_NAME).mkdir(parents=True)
    tone(folder / BOOK_NAME, 60)
    tone(folder / FOLDER_NAME / "01 Chapter.m4a", 20)
    tone(folder / FOLDER_NAME / "02 Chapter.m4a", 20)
    return folder


# MARK: - Simulators


class Simulator:
    """One named simulator; resetting it recreates it when the simulator gets stuck."""

    def __init__(self, name, runtime, device_type):
        self.name, self.runtime, self.device_type = name, runtime, device_type
        self.udid = self._find_or_create()

    def _find_or_create(self):
        devices = json.loads(run(["xcrun", "simctl", "list", "devices", "-j"], timeout=SIMCTL_TIMEOUT))["devices"]
        for runtime_id, entries in devices.items():
            for device in entries:
                if device["name"] != self.name:
                    continue
                if runtime_id == self.runtime["identifier"] and device.get("isAvailable", True):
                    return device["udid"]
                self._delete(device["udid"])
        return run(["xcrun", "simctl", "create", self.name, self.device_type, self.runtime["identifier"]],
                   timeout=SIMCTL_TIMEOUT).strip()

    @staticmethod
    def _delete(udid):
        try:
            subprocess.run(["xcrun", "simctl", "delete", udid], capture_output=True, timeout=SIMCTL_TIMEOUT)
        except subprocess.TimeoutExpired:
            raise SetupError(f"simulator {udid} is stuck and can't be deleted; quit Simulator/Device Hub and run "
                             "`killall -9 com.apple.CoreSimulator.CoreSimulatorService`, then run the check again")

    def shutdown(self):
        try:
            subprocess.run(["xcrun", "simctl", "shutdown", self.udid], capture_output=True, timeout=SIMCTL_TIMEOUT)
        except subprocess.TimeoutExpired:
            log(f"{self.name}: shutdown timed out")

    def reset(self):
        """Erase and boot. A simulator that hangs on any of it is deleted and recreated once."""
        for attempt in (1, 2):
            try:
                subprocess.run(["xcrun", "simctl", "shutdown", self.udid], capture_output=True, timeout=SIMCTL_TIMEOUT)
                run(["xcrun", "simctl", "erase", self.udid], timeout=SIMCTL_TIMEOUT)
                run(["xcrun", "simctl", "boot", self.udid], timeout=SIMCTL_TIMEOUT)
                run(["xcrun", "simctl", "bootstatus", self.udid, "-b"], timeout=BOOT_TIMEOUT)
                return
            except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
                if attempt == 2:
                    raise SetupError(f"{self.name} couldn't be reset even after recreating it: {error}")
                log(f"{self.name}: stuck resetting ({type(error).__name__}), recreating it")
                self._delete(self.udid)
                self.udid = run(["xcrun", "simctl", "create", self.name, self.device_type,
                                 self.runtime["identifier"]], timeout=SIMCTL_TIMEOUT).strip()

    def copy_fixtures(self, bundle_id, fixtures):
        container = run(["xcrun", "simctl", "get_app_container", self.udid, bundle_id, "data"], timeout=SIMCTL_TIMEOUT)
        documents = Path(container.strip()) / "Documents"
        documents.mkdir(exist_ok=True)
        shutil.copy(fixtures / BOOK_NAME, documents / BOOK_NAME)
        shutil.copytree(fixtures / FOLDER_NAME, documents / FOLDER_NAME, dirs_exist_ok=True)

    def screenshot(self, path):
        try:
            subprocess.run(["xcrun", "simctl", "io", self.udid, "screenshot", str(path)], capture_output=True,
                           timeout=SIMCTL_TIMEOUT)
        except subprocess.TimeoutExpired:
            pass


# MARK: - Running tests


def crash_reports_since(start, bundle_id, udid):
    """The app's crash reports from simulator `udid` written since `start`.

    Matches the bundle id and the simulator in the report's process path, so a crash from another build or another
    simulator (e.g. a dev session running alongside) doesn't count. A report without a process path still counts:
    a false alarm is better than a missed crash.
    """
    reports = []
    folder = Path.home() / "Library/Logs/DiagnosticReports"
    # macOS moves reports into Retired/ after a while
    for report in sorted([*folder.glob("*.ips"), *folder.glob("Retired/*.ips")]):
        try:
            if report.stat().st_mtime < start:
                continue
            header_line, body = report.read_text().split("\n", 1)
            header = json.loads(header_line)
            proc_path = json.loads(body).get("procPath", "")
        except (OSError, ValueError):
            continue
        if header.get("bundleID") == bundle_id and (not proc_path or f"/Devices/{udid}/" in proc_path):
            reports.append(report)
    return reports


def crash_summary(report):
    """Exception and the first frames of the crashed thread, from an .ips file."""
    try:
        data = json.loads(report.read_text().split("\n", 1)[1])
        exception = data.get("exception", {})
        thread = data["threads"][data["faultingThread"]]
        images = data.get("usedImages", [])
        frames = []
        for frame in thread.get("frames", [])[:12]:
            index = frame.get("imageIndex", -1)
            image = images[index].get("name", "?") if 0 <= index < len(images) else "?"
            frames.append(f"{image}  {frame.get('symbol', '?')}")
        return "\n".join([f"{exception.get('type', '?')} {exception.get('signal', '')}".strip()] + frames)
    except Exception as error:  # noqa: BLE001 — a summary is best effort; the file is still listed
        return f"(couldn't read {report.name}: {error})"


# xcodebuild's own words for an app crash during a UI test (5.22.1's launch crash logged "crashed in main")
CRASH_TEXT = ("crashed in ", "The app crashed", "unexpected exit, crash")
CRASH_REPORT_GRACE = 15


def log_reports_crash(text):
    return any(marker in text for marker in CRASH_TEXT)


class StepFailure:
    def __init__(self, message, crashed):
        self.message, self.crashed = message, crashed


def run_test(simulator, xctestrun, test, log_file, bundle_id):
    """Runs one UI test; returns None when it passed, else a StepFailure."""
    start = time.time()
    cmd = ["xcodebuild", "test-without-building", "-xctestrun", str(xctestrun),
           "-destination", f"platform=iOS Simulator,id={simulator.udid}",
           # Xcode 27's xcodebuild hangs after the tests unless diagnostics collection is off
           "-collect-test-diagnostics", "never",
           "-test-timeouts-enabled", "YES",
           "-default-test-execution-time-allowance", str(TEST_ALLOWANCE),
           "-maximum-test-execution-time-allowance", str(TEST_ALLOWANCE),
           f"-only-testing:{TEST_CLASS}/{test}"]
    with open(log_file, "w") as out:
        try:
            code = subprocess.run(cmd, stdout=out, stderr=subprocess.STDOUT, timeout=TEST_TIMEOUT).returncode
        except subprocess.TimeoutExpired:
            code = None
    text = log_file.read_text()
    crashes = crash_reports_since(start, bundle_id, simulator.udid)
    if code == 0 and f"{test}]' passed" in text and not crashes:
        return None
    # A crash report can land a few seconds after xcodebuild returns; a crash must never be retried
    deadline = time.time() + CRASH_REPORT_GRACE
    while not crashes and time.time() < deadline:
        time.sleep(3)
        crashes = crash_reports_since(start, bundle_id, simulator.udid)
    reasons = [line.split(" : ", 1)[-1] for line in text.splitlines() if "error: -[" in line][:3]
    if code is None:
        reasons.append(f"timed out after {TEST_TIMEOUT} s")
    for report in crashes:
        reasons.append(f"crash report {report.name}:\n{crash_summary(report)}")
    crashed = bool(crashes) or log_reports_crash(text)
    return StepFailure(f"{test}: " + ("\n".join(reasons) or f"failed (exit {code}), see {log_file}"), crashed)


def run_chain(simulator, chain, logs, bundle_id, attempt):
    """Runs scenarios in order on a freshly reset simulator, stopping at the first failure.

    `chain` is [(scenario, [step, …])], where a step is a callable (setup) or an (xctestrun, test) pair.
    Returns {scenario: None (passed) | StepFailure | "not run"}.
    """
    simulator.reset()
    outcome = {}
    failed = False
    for scenario, steps in chain:
        if failed:
            outcome[scenario] = "not run"
            continue
        for step in steps:
            if callable(step):
                # A setup step that errors or hangs (e.g. simctl) is a non-crash failure, so it gets the retry
                try:
                    step(simulator)
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError, OSError) as error:
                    simulator.screenshot(logs / f"{scenario}-failed-attempt{attempt}.png")
                    outcome[scenario] = StepFailure(f"setup: {error}", crashed=False)
                    failed = True
                    break
                continue
            xctestrun, test = step
            failure = run_test(simulator, xctestrun, test, logs / f"{scenario}-{test}-attempt{attempt}.log", bundle_id)
            if failure:
                simulator.screenshot(logs / f"{scenario}-failed-attempt{attempt}.png")
                outcome[scenario] = failure
                failed = True
                break
        else:
            simulator.screenshot(logs / f"{scenario}.png")
            outcome[scenario] = None
    return outcome


def run_with_retry(label, simulator, chain, logs, bundle_id):
    """One attempt; a failure without a crash report gets one more on a reset simulator.

    Returns [(label, scenario, status, message)] with status "passed" | "retried" | "failed" | "not run".
    """
    first = run_chain(simulator, chain, logs, bundle_id, attempt=1)
    failures = [f for f in first.values() if isinstance(f, StepFailure)]
    if not failures:
        return [(label, scenario, "passed", "") for scenario in first]
    if any(f.crashed for f in failures):
        log(f"{label}: crashed, no retry")
        return describe(label, first)
    log(f"{label}: failed without a crash report, retrying once on a reset simulator")
    second = run_chain(simulator, chain, logs, bundle_id, attempt=2)
    results = []
    for scenario, result in second.items():
        earlier = first.get(scenario)
        if result is None and isinstance(earlier, StepFailure):
            results.append((label, scenario, "retried", f"passed on retry; first attempt: {earlier.message}"))
        elif isinstance(result, StepFailure) and isinstance(earlier, StepFailure):
            results.append((label, scenario, "failed",
                            f"failed twice; second attempt: {result.message}\nfirst attempt: {earlier.message}"))
        else:
            results += describe(label, {scenario: result})
    return results


def describe(label, outcome):
    rows = []
    for scenario, result in outcome.items():
        if result is None:
            rows.append((label, scenario, "passed", ""))
        elif result == "not run":
            rows.append((label, scenario, "not run", "an earlier scenario failed"))
        else:
            rows.append((label, scenario, "failed", result.message))
    return rows


# MARK: - Main


def check(args):
    started = datetime.datetime.now()
    out = Path(args.out or tempfile.mkdtemp(prefix="bookplayer-release-check-"))
    out.mkdir(parents=True, exist_ok=True)
    results, notes = [], []

    minimum, newest = deployment_target_major(), sdk_major()
    runtimes = json.loads(run(["xcrun", "simctl", "list", "runtimes", "-j"], timeout=SIMCTL_TIMEOUT))["runtimes"]
    plan = []
    for major in supported_majors(minimum, newest):
        if major in SKIPPED_MAJORS:
            notes.append(f"iOS {major} skipped: {SKIPPED_MAJORS[major]}")
            continue
        choice = runtime_for(major, runtimes)
        if not choice:
            raise SetupError(f"no iOS {major} simulator runtime that runs an iPhone is installed. Install one "
                             f"(Xcode → Settings → Components, or `xcodebuild -downloadPlatform iOS -buildVersion "
                             f"{major}.<minor>`), then run the check again")
        plan.append((major, *choice))
    if not plan:
        raise SetupError("no iOS version to test")
    log("testing on " + ", ".join(f"iOS {r['version']}" for _, r, _ in plan))

    if args.version and subprocess.run(["git", "-C", str(REPO), "rev-parse", "-q", "--verify", f"refs/tags/{args.version}"],
                                       capture_output=True).returncode == 0:
        raise SetupError(f"tag {args.version} already exists; --version is the release being prepared, which isn't "
                         "tagged yet (to recheck a shipped build, run without --version)")
    tag = args.previous or previous_tag()
    ensure_debug_xcconfig(REPO)
    products = build(REPO, out / "DerivedData")
    xctestrun = next(products.glob(f"{SCHEME}_*.xctestrun"), None)
    if not xctestrun:
        raise SetupError(f"the build produced no {SCHEME} .xctestrun in {products}")
    candidate = products / "Release-iphonesimulator/BookPlayer.app"
    with open(candidate / "Info.plist", "rb") as f:
        bundle_id = plistlib.load(f)["CFBundleIdentifier"]
    previous = retarget(xctestrun, previous_app(tag, out), "previous.xctestrun")
    fixtures = make_fixtures(out / "fixtures")

    def copy_fixtures(simulator):
        simulator.copy_fixtures(bundle_id, fixtures)

    setup_errors = []
    for major, runtime, device_type in plan:
        label = f"iOS {runtime['version']}"
        logs = out / f"ios-{runtime['version']}"
        logs.mkdir(exist_ok=True)
        simulators = []
        try:
            main = Simulator(f"{SIMULATOR_PREFIX} {major}", runtime, device_type)
            simulators.append(main)
            upgrade = Simulator(f"{SIMULATOR_PREFIX} {major} Upgrade", runtime, device_type)
            simulators.append(upgrade)

            for simulator, chain in [
                (main, [
                    ("fresh", [(xctestrun, "testFreshLaunch")]),
                    ("import", [copy_fixtures, (xctestrun, "testImport")]),
                    ("playback", [(xctestrun, "testPlayback")]),
                ]),
                (upgrade, [
                    ("upgrade", [(previous, "testFreshLaunch"), copy_fixtures, (previous, "testSeedPreviousRelease"),
                                 (xctestrun, "testUpgradeContinuity")]),
                ]),
            ]:
                rows = run_with_retry(label, simulator, chain, logs, bundle_id)
                for row in rows:
                    log(f"{row[0]} {row[1]}: {row[2]}")
                results += rows
        except (SetupError, subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
            # Keep what already ran and carry on with the other versions; the report says what couldn't run
            setup_errors.append(f"{label} could not run: {error}")
            log(setup_errors[-1])
            ran = {scenario for row_label, scenario, _, _ in results if row_label == label}
            results += [(label, scenario, "not run", "could not run (see notes)")
                        for scenario in ("fresh", "import", "playback", "upgrade") if scenario not in ran]
        finally:
            for simulator in simulators:
                simulator.shutdown()

    notes += setup_errors
    passed = not setup_errors and all(status in ("passed", "retried") for _, _, status, _ in results)
    if passed and args.version:
        # Reused as the next release's "previous" only if <version>'s tag turns out to be this commit
        # plus the version bump (see cached_app)
        dirty = bool(git("status", "--porcelain", "--untracked-files=no"))
        cache_app(candidate, args.version, git("rev-parse", "HEAD"), dirty)
        prune_cache(keep=[args.version, tag, PACKAGES.name])
    if not args.keep_build:
        shutil.rmtree(out / "DerivedData", ignore_errors=True)

    write_report(out, started, tag, results, notes, passed, could_not_run=bool(setup_errors))
    return 2 if setup_errors else (0 if passed else 1)


def prune_cache(keep):
    for entry in CACHE.iterdir() if CACHE.exists() else []:
        if entry.name not in keep:
            shutil.rmtree(entry, ignore_errors=True)


ICONS = {"passed": "✅", "retried": "⚠️", "failed": "❌", "not run": "➖"}


def write_report(out, started, tag, results, notes, passed, could_not_run=False):
    minutes = (datetime.datetime.now() - started).total_seconds() / 60
    retried = any(status == "retried" for _, _, status, _ in results)
    if could_not_run:
        verdict = "COULD NOT RUN (partial results)"
    else:
        verdict = "FAILED" if not passed else ("PASSED (with a retry)" if retried else "PASSED")
    lines = [f"# Release check: {verdict}", "",
             f"Previous release for the upgrade scenario: {tag}. Took {minutes:.1f} min.", ""]
    lines += [f"- {note}" for note in notes] + ([""] if notes else [])
    lines += ["| iOS | Scenario | Result |", "|---|---|---|"]
    for label, scenario, status, message in results:
        first = message.splitlines()[0] if message else status
        lines.append(f"| {label} | {scenario} | {ICONS[status]} {first} |")
    for label, scenario, status, message in results:
        if status in ("failed", "retried") and message:
            lines += ["", f"## {label} · {scenario} ({status})", "", "```", message, "```"]
    (out / "report.md").write_text("\n".join(lines) + "\n")
    (out / "report.json").write_text(json.dumps({
        "passed": passed, "could_not_run": could_not_run, "previous": tag, "notes": notes,
        "results": [{"ios": l, "scenario": s, "status": st, "message": m} for l, s, st, m in results],
    }, indent=2))
    print("\n".join(lines))
    print(f"\nReport, logs and screenshots: {out}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--version", help="version being released; a passing build is cached under it")
    parser.add_argument("--previous", help="previous release tag (default: the latest tag reachable from HEAD)")
    parser.add_argument("--out", help="folder for the report, logs and screenshots (default: a new temp folder)")
    parser.add_argument("--keep-build", action="store_true", help="keep the DerivedData folder")
    args = parser.parse_args()
    try:
        sys.exit(check(args))
    except SetupError as error:
        print(f"\nRelease check could not run: {error}", file=sys.stderr)
        sys.exit(2)
    except subprocess.CalledProcessError as error:
        print(f"\nRelease check could not run: {' '.join(error.cmd)} failed:\n{error.stderr}", file=sys.stderr)
        sys.exit(2)
    except subprocess.TimeoutExpired as error:
        print(f"\nRelease check could not run: {' '.join(error.cmd)} timed out", file=sys.stderr)
        sys.exit(2)
    except Exception:  # noqa: BLE001 — a bug in this script must never read as a failed release (exit 1)
        traceback.print_exc()
        print("\nRelease check could not run: unexpected error in release_check.py (traceback above)", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
