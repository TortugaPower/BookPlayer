#!/usr/bin/env python3
"""Attach a release's commits in Sentry, so a `Fixes <SHORT-ID>` line resolves its issue in the release that ships it.

The commits are everything after the previous release's version tag. They go to Sentry as one full list, filed under
the repository Sentry links to GitHub. Letting Sentry work out a ref range itself (`sentry-cli releases set-commits
--auto`, or `--commit A..B`) keeps only the newest 100 commits, and `--local` files them under a repository named after
the git remote ("origin"). A list keeps up to 1000 (Sentry's `releases.set-commits.max-commits`).

The same file is in TortugaPower/bookplayer-android (scripts/sentry-commits/) and TortugaPower/BookPlayer
(ci_scripts/). Change both.

Android (release.yml, a full clone):
    sentry_release_commits.py --release <bundle id>@<version>+<code> --version <version> --head <sha> \\
        --repo TortugaPower/bookplayer-android --project android-bookplayer --source git
iOS (Xcode Cloud, a clone without history):
    sentry_release_commits.py --archive <.xcarchive> --head <sha> \\
        --repo TortugaPower/BookPlayer --project bookplayer --source github

The previous release is the highest version tag below this version, read from GitHub with `git ls-remote` (both repos
are public). --source git lists the commits from the checkout, with the files each one changed (Sentry's suspect
commits use them); --source github asks GitHub's compare API, without the files (that's one request per commit).
--dry-run reads everything and sends nothing. The Sentry calls authenticate with SENTRY_AUTH_TOKEN (project:releases).

Exit code 0 = attached (or a dry run), 1 = it couldn't.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import plistlib
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

SENTRY_ORG = "tortuga-power"
SENTRY_URL = os.environ.get("SENTRY_URL", "https://sentry.io").rstrip("/")
GITHUB_API = "https://api.github.com"
TIMEOUT = 60
# What Sentry reads in a commit message (simplified): fix, fixes, fixed, close(s/d), resolve(s/d), then short ids.
# Only for the summary; Sentry does the resolving. An id must end there, so `Fixes ANDROID-BOOKPLAYER-<id>` in a
# commit that documents the convention isn't counted.
SHORT_ID = r"[A-Z0-9_-]+-[A-Z0-9]+(?![\w<-])"
FIX_LINE = re.compile(rf"(?i:\b(?:close|fix|resolve)(?:s|d|es|ed)?)\s+({SHORT_ID}(?:\s*,\s*{SHORT_ID})*)")
# Sentry drops a commit whose message says this.
SKIP_MARKER = "#skipsentry"


class Failure(Exception):
    pass


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
    if result.returncode != 0:
        raise Failure(f"`{' '.join(cmd[:3])}` failed: {result.stderr.strip()[-300:]}")
    return result.stdout


def http(method: str, url: str, body: object = None, headers: dict | None = None) -> object:
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={"Accept": "application/json", **(headers or {})})
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        detail = error.read()[:300].decode(errors="replace")
        raise Failure(f"{method} {url.split('?')[0]} answered {error.code}: {detail}") from None


def version_key(text: str) -> tuple | None:
    """(6, 0, 1) for "6.0.1", trailing zeros dropped so "6.0" equals "6.0.0"; None for a tag that isn't a version."""
    if not re.fullmatch(r"\d+(\.\d+)*", text):
        return None
    parts = [int(part) for part in text.split(".")]
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def remote_tags(repo: str, run=run) -> dict[str, str]:
    """{tag: commit} for the repo's version tags. An annotated tag lists its commit on its `^{}` line."""
    tags, peeled = {}, {}
    for line in run(["git", "ls-remote", "--tags", f"https://github.com/{repo}.git"]).splitlines():
        sha, _, ref = line.partition("\t")
        name = ref[len("refs/tags/"):]
        if name.endswith("^{}"):
            peeled[name[:-3]] = sha
        else:
            tags[name] = sha
    return {name: peeled.get(name, sha) for name, sha in tags.items() if version_key(name)}


def previous_tag(tags: dict[str, str], version: str) -> tuple[str | None, str | None]:
    """The highest version tag below `version` (its own tag may exist already), as (tag, commit)."""
    current = version_key(version)
    earlier = [name for name in tags if version_key(name) < current]
    if not earlier:
        return None, None
    name = max(earlier, key=version_key)
    return name, tags[name]


def patch_set(name_status: str) -> list[dict]:
    """Sentry's patch set (A, M or D per path) from `git log --name-status` lines. A rename is a delete and an add."""
    files = []
    for line in name_status.splitlines():
        status, *paths = line.split("\t")
        if not paths:
            continue
        kind = status[:1]
        if kind == "R":
            files += [{"path": paths[0], "type": "D"}, {"path": paths[-1], "type": "A"}]
        elif kind == "C":
            files.append({"path": paths[-1], "type": "A"})
        elif kind in ("A", "D"):
            files.append({"path": paths[0], "type": kind})
        else:  # M, T (a type change), U
            files.append({"path": paths[0], "type": "M"})
    return files


def git_commits(repo: str, base: str | None, head: str, run=run) -> list[dict]:
    """The commits after `base` up to `head`, newest first, read from the checkout. A merge lists no files."""
    revs = [f"{base}..{head}"] if base else ["-1", head]
    log = run(["git", "log", "--format=%x1e%H%x1f%an%x1f%ae%x1f%aI%x1f%B%x1f", "--name-status", *revs])
    commits = []
    for record in log.split("\x1e")[1:]:
        sha, name, email, date, message, files = record.split("\x1f")
        commits.append({"id": sha, "repository": repo, "message": message.strip(), "author_name": name,
                        "author_email": email, "timestamp": date, "patch_set": patch_set(files.strip())})
    return commits


def github_commits(repo: str, base: str | None, head: str, http=http) -> list[dict]:
    """The same list from GitHub's compare API, which pages them oldest first."""
    if base:
        found, page = [], 1
        while True:
            compare = http("GET", f"{GITHUB_API}/repos/{repo}/compare/{base}...{head}?per_page=100&page={page}")
            batch = compare.get("commits") or []
            found += batch
            if not batch or len(found) >= compare.get("total_commits", 0):
                break
            page += 1
        found.reverse()
    else:
        found = [http("GET", f"{GITHUB_API}/repos/{repo}/commits/{head}")]
    return [{"id": commit["sha"], "repository": repo, "message": commit["commit"]["message"].strip(),
             "author_name": commit["commit"]["author"]["name"], "author_email": commit["commit"]["author"]["email"],
             "timestamp": commit["commit"]["author"]["date"]} for commit in found]


def fix_ids(commits: list[dict]) -> list[str]:
    ids = []
    for commit in commits:
        for match in FIX_LINE.finditer(commit["message"]):
            ids += [short_id.strip() for short_id in match.group(1).split(",") if short_id.strip() not in ids]
    return ids


def archive_release(archive: str) -> tuple[str, str]:
    """(release, version) as the Sentry SDK names the release: <bundle id>@<version>+<build>, from the archived app."""
    plists = glob.glob(os.path.join(archive, "Products", "Applications", "*.app", "Info.plist"))
    if len(plists) != 1:
        raise Failure(f"expected one app in {archive}, found {len(plists)}")
    with open(plists[0], "rb") as file:
        info = plistlib.load(file)
    version = info["CFBundleShortVersionString"]
    return f"{info['CFBundleIdentifier']}@{version}+{info['CFBundleVersion']}", version


def attach(release: str, project: str, commits: list[dict], token: str, http=http) -> int:
    """Creates the release if it's missing (Sentry answers 208 when it exists), replaces its commits, and returns how
    many Sentry now holds."""
    headers = {"Authorization": f"Bearer {token}"}
    releases = f"{SENTRY_URL}/api/0/organizations/{SENTRY_ORG}/releases/"
    http("POST", releases, {"version": release, "projects": [project]}, headers)
    answer = http("PUT", f"{releases}{urllib.parse.quote(release, safe='')}/", {"commits": commits}, headers)
    return answer.get("commitCount")


def main(argv: list[str] | None = None, run=run, http=http) -> int:
    parser = argparse.ArgumentParser(description="Attach a release's commits in Sentry.")
    parser.add_argument("--release", help="the Sentry release, <bundle id>@<version>+<build>")
    parser.add_argument("--version", help="the release's version, e.g. 1.3.1")
    parser.add_argument("--archive", help="an .xcarchive to read the release and version from instead")
    parser.add_argument("--head", required=True, help="the commit being released")
    parser.add_argument("--repo", required=True, help="the GitHub repository, as Sentry names it: owner/name")
    parser.add_argument("--project", required=True, help="the Sentry project")
    parser.add_argument("--source", choices=("git", "github"), required=True, help="where to list the commits from")
    parser.add_argument("--dry-run", action="store_true", help="read everything, send nothing to Sentry")
    args = parser.parse_args(argv)
    if not args.archive and not (args.release and args.version):
        parser.error("give --archive, or --release and --version")
    try:
        release, version = archive_release(args.archive) if args.archive else (args.release, args.version)
        if not version_key(version):
            raise Failure(f"{version!r} isn't a version")
        tag, base = previous_tag(remote_tags(args.repo, run), version)
        if args.source == "git":
            commits = git_commits(args.repo, base, args.head, run)
        else:
            commits = github_commits(args.repo, base, args.head, http)
        if not commits:
            raise Failure(f"no commits after {tag} up to {args.head}")
        print(f"{release}: {len(commits)} commits after {tag or 'no earlier tag'}; "
              f"fix lines: {', '.join(fix_ids(commits)) or 'none'}")
        if args.dry_run:
            return 0
        token = os.environ.get("SENTRY_AUTH_TOKEN")
        if not token:
            raise Failure("SENTRY_AUTH_TOKEN isn't set")
        expected = sum(SKIP_MARKER not in commit["message"] for commit in commits)
        held = attach(release, args.project, commits, token, http)
        if held != expected:
            raise Failure(f"Sentry holds {held} of the release's {expected} commits")
        print(f"Sentry release {release} holds all {held} commits")
        return 0
    except (Failure, OSError, subprocess.SubprocessError, ValueError, KeyError, AttributeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
