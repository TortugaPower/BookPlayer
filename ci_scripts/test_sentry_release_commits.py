import contextlib
import io
import os
import plistlib
import tempfile
import unittest
import urllib.error
from unittest import mock

import sentry_release_commits as src

REPO = "TortugaPower/bookplayer-android"
LS_REMOTE = "\n".join([
    "aaa1\trefs/tags/1.2.0",             # lightweight
    "bbb1\trefs/tags/1.3.0",             # annotated: the tag object...
    "bbb2\trefs/tags/1.3.0^{}",          # ...and its commit
    "ccc1\trefs/tags/1.10.0",
    "ddd1\trefs/tags/nightly",
    "eee1\trefs/tags/1.3.0-beta",
])


def git_record(sha, name, email, date, message, files=""):
    return f"\x1e{sha}\x1f{name}\x1f{email}\x1f{date}\x1f{message}\n\x1f\n\n{files}\n"


class TagTests(unittest.TestCase):
    def test_keeps_version_tags_and_prefers_an_annotated_tags_commit(self):
        tags = src.remote_tags(REPO, run=lambda cmd: LS_REMOTE)
        self.assertEqual(tags, {"1.2.0": "aaa1", "1.3.0": "bbb2", "1.10.0": "ccc1"})

    def test_previous_tag_compares_numbers_not_text(self):
        tags = {"1.2.0": "a", "1.3.0": "b", "1.10.0": "c", "1.9.1": "d"}
        self.assertEqual(src.previous_tag(tags, "1.3.1"), ("1.3.0", "b"))
        self.assertEqual(src.previous_tag(tags, "1.10.0"), ("1.9.1", "d"))  # its own tag exists already
        self.assertEqual(src.previous_tag(tags, "2"), ("1.10.0", "c"))
        self.assertEqual(src.previous_tag(tags, "1.0"), (None, None))

    def test_trailing_zeros_dont_make_a_version_newer(self):
        self.assertEqual(src.version_key("6.0"), src.version_key("6.0.0"))
        self.assertEqual(src.previous_tag({"6.0.0": "a", "5.22.2": "b"}, "6.0"), ("5.22.2", "b"))
        self.assertIsNone(src.version_key("1.3.0-beta"))


class GitCommitTests(unittest.TestCase):
    def test_reads_each_commit_with_its_files_newest_first(self):
        log = (git_record("c2", "Gianni", "g@example.com", "2026-10-26T10:00:00-05:00",
                          "fix(sync): one engine\n\nFixes ANDROID-BOOKPLAYER-2F\nFixes ANDROID-BOOKPLAYER-2E",
                          "M\tcore/A.kt\nD\tapp/Old.kt\nA\tapp/New.kt\nA\tapp/Added.kt\nD\tapp/Gone.kt\nT\tapp/link")
               + git_record("c1", "Gianni", "g@example.com", "2026-10-20T10:00:00-05:00", "Merge pull request #1"))
        calls = []
        commits = src.git_commits(REPO, "base", "head", run=lambda cmd: calls.append(cmd) or log)
        self.assertEqual(calls[0][-1], "base..head")
        self.assertIn("--no-renames", calls[0])  # finding renames would read file contents a partial clone lacks
        self.assertEqual([c["id"] for c in commits], ["c2", "c1"])
        self.assertEqual(commits[0]["message"], "fix(sync): one engine\n\nFixes ANDROID-BOOKPLAYER-2F\nFixes ANDROID-BOOKPLAYER-2E")
        self.assertEqual(commits[0]["repository"], REPO)
        self.assertEqual(commits[0]["patch_set"], [
            {"path": "core/A.kt", "type": "M"}, {"path": "app/Old.kt", "type": "D"},
            {"path": "app/New.kt", "type": "A"}, {"path": "app/Added.kt", "type": "A"},
            {"path": "app/Gone.kt", "type": "D"}, {"path": "app/link", "type": "M"}])
        self.assertEqual(commits[1]["patch_set"], [])  # git lists no files for a merge

    def test_without_an_earlier_tag_reads_only_the_head(self):
        calls = []
        src.git_commits(REPO, None, "head", run=lambda cmd: calls.append(cmd) or git_record("h", "n", "e", "d", "m"))
        self.assertEqual(calls[0][-2:], ["-1", "head"])


class FetchHistoryTests(unittest.TestCase):
    def run_recording(self, shallow):
        calls = []

        def run(cmd):
            calls.append(cmd)
            return f"{str(shallow).lower()}\n" if cmd[1] == "rev-parse" else ""
        return calls, run

    def test_a_shallow_checkout_fetches_commits_and_trees_for_both_ends(self):
        calls, run = self.run_recording(shallow=True)
        src.fetch_history("base", "head", run=run)
        self.assertEqual(calls[1], ["git", "fetch", "--quiet", "--filter=blob:none", "--unshallow", "--no-tags",
                                    "origin", "head", "base"])

    def test_without_an_earlier_tag_only_the_head_is_fetched(self):
        calls, run = self.run_recording(shallow=True)
        src.fetch_history(None, "head", run=run)
        self.assertEqual(calls[1][-2:], ["origin", "head"])

    def test_a_full_checkout_fetches_nothing(self):
        calls, run = self.run_recording(shallow=False)
        src.fetch_history("base", "head", run=run)
        self.assertEqual(len(calls), 1)


class FixIdTests(unittest.TestCase):
    def test_finds_what_sentry_reads(self):
        commits = [{"message": "fix(sync): x\n\nFixes ANDROID-BOOKPLAYER-2F\nFixes ANDROID-BOOKPLAYER-2E"},
                   {"message": "Resolves BOOKPLAYER-11HV, BOOKPLAYER-13HQ,BOOKPLAYER-11HV\nfixed ANDROID-BOOKPLAYER-2F"},
                   {"message": "fix(player): a re-entrant fix-up\nfixes the bug"},
                   {"message": "docs: put `Fixes ANDROID-BOOKPLAYER-<id>` in the commit body"}]
        self.assertEqual(src.fix_ids(commits), ["ANDROID-BOOKPLAYER-2F", "ANDROID-BOOKPLAYER-2E",
                                                "BOOKPLAYER-11HV", "BOOKPLAYER-13HQ"])


class ArchiveTests(unittest.TestCase):
    def test_names_the_release_from_the_archived_app(self):
        with tempfile.TemporaryDirectory() as archive:
            app = os.path.join(archive, "Products", "Applications", "BookPlayer.app")
            os.makedirs(app)
            with open(os.path.join(app, "Info.plist"), "wb") as file:
                plistlib.dump({"CFBundleIdentifier": "com.tortugapower.audiobookplayer",
                               "CFBundleShortVersionString": "6.0.2", "CFBundleVersion": "193"},
                              file, fmt=plistlib.FMT_BINARY)
            self.assertEqual(src.archive_release(archive), ("com.tortugapower.audiobookplayer@6.0.2+193", "6.0.2"))

    def test_an_archive_without_an_app_fails(self):
        with tempfile.TemporaryDirectory() as archive:
            with self.assertRaises(src.Failure):
                src.archive_release(archive)


class HttpTests(unittest.TestCase):
    def test_an_error_answer_names_the_call_but_not_its_headers(self):
        answer = urllib.error.HTTPError("https://sentry.io/api/0/x/?q=1", 403, "Forbidden", {},
                                        io.BytesIO(b'{"detail": "You do not have permission"}'))
        with mock.patch("urllib.request.urlopen", side_effect=answer):
            with self.assertRaises(src.Failure) as raised:
                src.http("PUT", "https://sentry.io/api/0/x/?q=1", {"commits": []}, {"Authorization": "Bearer t0ken"})
        message = str(raised.exception)
        self.assertIn("PUT https://sentry.io/api/0/x/ answered 403", message)
        self.assertIn("You do not have permission", message)
        self.assertNotIn("t0ken", message)

    def test_sends_the_headers_and_reads_the_json_answer(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = b'{"commitCount": 3}'
        with mock.patch("urllib.request.urlopen", return_value=response) as urlopen:
            self.assertEqual(src.http("PUT", "https://sentry.io/x/", {"a": 1}, {"Authorization": "Bearer t0ken"}),
                             {"commitCount": 3})
        request = urlopen.call_args[0][0]
        self.assertEqual(request.get_header("Authorization"), "Bearer t0ken")
        self.assertEqual(request.get_header("Content-type"), "application/json")
        self.assertEqual(request.data, b'{"a": 1}')


class MainTests(unittest.TestCase):
    ARGS = ["--release", "com.tortugapower.audiobookplayer@1.3.1+26", "--version", "1.3.1", "--head", "head",
            "--repo", REPO, "--project", "android-bookplayer"]
    LOG = (git_record("c2", "n", "e", "2026-10-26T10:00:00Z", "fix: x\n\nFixes ANDROID-BOOKPLAYER-2F")
           + git_record("c1", "n", "e", "2026-10-20T10:00:00Z", "chore: y #skipsentry"))

    def run_main(self, args, http, token="t0ken"):
        def run(cmd):
            return {"ls-remote": LS_REMOTE, "rev-parse": "false\n"}.get(cmd[1], self.LOG)
        out, err = io.StringIO(), io.StringIO()
        env = {"SENTRY_AUTH_TOKEN": token} if token else {}
        with mock.patch.dict(os.environ, env, clear=True), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = src.main(args, run=run, http=http)
        return code, out.getvalue(), err.getvalue()

    def test_dry_run_reads_but_sends_nothing(self):
        http = mock.Mock()
        code, out, _ = self.run_main(self.ARGS + ["--dry-run"], http, token=None)
        self.assertEqual(code, 0)
        self.assertIn("2 commits after 1.3.0; fix lines: ANDROID-BOOKPLAYER-2F", out)
        http.assert_not_called()

    def test_creates_the_release_then_replaces_its_commits(self):
        calls = []

        def http(method, url, body=None, headers=None):
            calls.append((method, url, body, headers))
            return {"commitCount": 1} if method == "PUT" else {}

        code, out, _ = self.run_main(self.ARGS, http)
        self.assertEqual(code, 0, out)
        (post, put) = calls
        self.assertEqual(post[0], "POST")
        self.assertEqual(post[2], {"version": "com.tortugapower.audiobookplayer@1.3.1+26", "projects": ["android-bookplayer"]})
        self.assertEqual(put[0], "PUT")
        self.assertTrue(put[1].endswith("/organizations/tortuga-power/releases/com.tortugapower.audiobookplayer%401.3.1%2B26/"))
        self.assertEqual([c["id"] for c in put[2]["commits"]], ["c2", "c1"])
        self.assertEqual(put[3], {"Authorization": "Bearer t0ken"})
        self.assertIn("holds all 1 commits", out)  # Sentry drops the #skipsentry one
        self.assertNotIn("t0ken", out)

    def test_fewer_commits_in_sentry_than_sent_fails(self):
        code, _, err = self.run_main(self.ARGS, lambda *a, **k: {"commitCount": 0})
        self.assertEqual(code, 1)
        self.assertIn("holds 0 of the release's 1 commits", err)

    def test_a_sentry_error_fails(self):
        def http(method, url, body=None, headers=None):
            raise src.Failure("PUT https://sentry.io/api/0/... answered 403: no permission")
        code, _, err = self.run_main(self.ARGS, http)
        self.assertEqual(code, 1)
        self.assertIn("answered 403", err)

    def test_no_token_fails_before_any_call(self):
        http = mock.Mock()
        code, _, err = self.run_main(self.ARGS, http, token=None)
        self.assertEqual(code, 1)
        self.assertIn("SENTRY_AUTH_TOKEN", err)
        http.assert_not_called()


if __name__ == "__main__":
    unittest.main()
