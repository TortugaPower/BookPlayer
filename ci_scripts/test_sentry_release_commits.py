import contextlib
import io
import os
import plistlib
import tempfile
import unittest
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


def commit_json(sha, message, date="2026-10-20T10:00:00Z"):
    return {"sha": sha, "commit": {"message": message, "author": {"name": "Gianni", "email": "g@example.com", "date": date}}}


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
                          "M\tcore/A.kt\nR087\tapp/Old.kt\tapp/New.kt\nA\tapp/Added.kt\nD\tapp/Gone.kt")
               + git_record("c1", "Gianni", "g@example.com", "2026-10-20T10:00:00-05:00", "Merge pull request #1"))
        calls = []
        commits = src.git_commits(REPO, "base", "head", run=lambda cmd: calls.append(cmd) or log)
        self.assertEqual(calls[0][-1], "base..head")
        self.assertEqual([c["id"] for c in commits], ["c2", "c1"])
        self.assertEqual(commits[0]["message"], "fix(sync): one engine\n\nFixes ANDROID-BOOKPLAYER-2F\nFixes ANDROID-BOOKPLAYER-2E")
        self.assertEqual(commits[0]["repository"], REPO)
        self.assertEqual(commits[0]["patch_set"], [
            {"path": "core/A.kt", "type": "M"}, {"path": "app/Old.kt", "type": "D"},
            {"path": "app/New.kt", "type": "A"}, {"path": "app/Added.kt", "type": "A"},
            {"path": "app/Gone.kt", "type": "D"}])
        self.assertEqual(commits[1]["patch_set"], [])  # git lists no files for a merge

    def test_without_an_earlier_tag_reads_only_the_head(self):
        calls = []
        src.git_commits(REPO, None, "head", run=lambda cmd: calls.append(cmd) or git_record("h", "n", "e", "d", "m"))
        self.assertEqual(calls[0][-2:], ["-1", "head"])


class GitHubCommitTests(unittest.TestCase):
    def test_follows_the_pages_and_returns_newest_first(self):
        pages = {1: [commit_json(f"s{i}", "m") for i in range(100)], 2: [commit_json(f"s{i}", "m") for i in range(100, 150)]}
        urls = []

        def fetch(method, url, body=None, headers=None):
            urls.append(url)
            page = int(url.rsplit("page=", 1)[1])
            return {"total_commits": 150, "commits": pages[page]}

        commits = src.github_commits("TortugaPower/BookPlayer", "base", "head", http=fetch)
        self.assertEqual(len(commits), 150)
        self.assertEqual((commits[0]["id"], commits[-1]["id"]), ("s149", "s0"))
        self.assertEqual(len(urls), 2)
        self.assertIn("/compare/base...head?per_page=100&page=1", urls[0])
        self.assertNotIn("patch_set", commits[0])

    def test_without_an_earlier_tag_reads_only_the_head(self):
        fetch = mock.Mock(return_value=commit_json("h", "m"))
        commits = src.github_commits("TortugaPower/BookPlayer", None, "head", http=fetch)
        self.assertEqual([c["id"] for c in commits], ["h"])
        self.assertTrue(fetch.call_args[0][1].endswith("/commits/head"))


class FixIdTests(unittest.TestCase):
    def test_finds_what_sentry_reads(self):
        commits = [{"message": "fix(sync): x\n\nFixes ANDROID-BOOKPLAYER-2F\nFixes ANDROID-BOOKPLAYER-2E"},
                   {"message": "Resolves BOOKPLAYER-11HV, BOOKPLAYER-13HQ\nfixed ANDROID-BOOKPLAYER-2F"},
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


class MainTests(unittest.TestCase):
    ARGS = ["--release", "com.tortugapower.audiobookplayer@1.3.1+26", "--version", "1.3.1", "--head", "head",
            "--repo", REPO, "--project", "android-bookplayer", "--source", "git"]
    LOG = (git_record("c2", "n", "e", "2026-10-26T10:00:00Z", "fix: x\n\nFixes ANDROID-BOOKPLAYER-2F")
           + git_record("c1", "n", "e", "2026-10-20T10:00:00Z", "chore: y #skipsentry"))

    def run_main(self, args, http, token="t0ken"):
        def run(cmd):
            return LS_REMOTE if cmd[1] == "ls-remote" else self.LOG
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

    def test_a_sentry_error_fails_without_the_token(self):
        def http(method, url, body=None, headers=None):
            raise src.Failure("PUT https://sentry.io/api/0/... answered 403: no permission")
        code, out, err = self.run_main(self.ARGS, http)
        self.assertEqual(code, 1)
        self.assertNotIn("t0ken", out + err)

    def test_no_token_fails_before_any_call(self):
        http = mock.Mock()
        code, _, err = self.run_main(self.ARGS, http, token=None)
        self.assertEqual(code, 1)
        self.assertIn("SENTRY_AUTH_TOKEN", err)
        http.assert_not_called()


if __name__ == "__main__":
    unittest.main()
