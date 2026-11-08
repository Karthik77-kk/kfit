"""Tests for ensure_kfit_latest.py and the workflows that wire it in.

Run: python3 -m unittest discover -s .github/scripts -p 'test_*.py' -v
"""

from __future__ import annotations

import importlib.util
import json
import re
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"

_spec = importlib.util.spec_from_file_location("ensure_kfit_latest", SCRIPTS / "ensure_kfit_latest.py")
guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(guard)

try:
    import yaml
except ImportError:  # pragma: no cover - PyYAML ships on GitHub's ubuntu runners
    yaml = None

REPO = "owner/kfit"


def rel(tag, assets=("kfit.apk",), draft=False, prerelease=False):
    return {"tag_name": tag, "draft": draft, "prerelease": prerelease, "assets": list(assets)}


def jarvis(build):
    return rel(f"jarvis-v1.0.{build}", assets=("jarvis.apk", "jarvis.apk.sha256"))


class FakeGh:
    """Stands in for the gh CLI: answers the three calls the guard makes."""

    def __init__(self, releases, latest, fail=(), on_edit=None, stuck=False):
        self.releases = list(releases)
        self.latest = latest
        self.fail = set(fail)  # any of "latest", "list", "edit"
        self.on_edit = on_edit
        self.stuck = stuck  # edits "succeed" but Latest never changes
        self.edits = []
        self.list_calls = 0

    def __call__(self, args):
        args = list(args)
        if args == ["api", f"repos/{REPO}/releases/latest"]:
            if "latest" in self.fail:
                return 1, "", "gh: Server Error (HTTP 500)"
            if self.latest is None:
                return 1, '{"message":"Not Found","status":"404"}', "gh: Not Found (HTTP 404)"
            return 0, json.dumps({"tag_name": self.latest}), ""
        if args == ["api", f"repos/{REPO}/releases?per_page=100", "--paginate", "--jq", guard.RELEASES_JQ]:
            self.list_calls += 1
            if "list" in self.fail:
                return 1, "", "gh: Bad credentials (HTTP 401)"
            return 0, "".join(json.dumps(r) + "\n" for r in self.releases), ""
        if len(args) == 6 and args[:2] == ["release", "edit"] and args[3:] == ["--repo", REPO, "--latest"]:
            if "edit" in self.fail:
                return 1, "", "HTTP 403: Resource not accessible by integration"
            if self.on_edit:
                self.on_edit(self, args[2])
            self.edits.append(args[2])
            if not self.stuck:
                self.latest = args[2]
            return 0, "", ""
        raise AssertionError(f"unexpected gh call: {args}")


def run(fake, dry_run=False):
    logs = []
    sleeps = []
    code = guard.ensure(fake, REPO, dry_run=dry_run, log=logs.append, sleep=sleeps.append)
    return code, "\n".join(logs), sleeps


class KfitVersionTest(unittest.TestCase):
    def test_parses_kfit_tags(self):
        self.assertEqual(guard.kfit_version("v3.0.717"), (3, 0, 717))
        self.assertEqual(guard.kfit_version("v10.2.3"), (10, 2, 3))

    def test_rejects_other_tags(self):
        for tag in ["jarvis-v1.0.95", "v3.0.717-build-5", "3.0.717", "v3.0", "kfit-v3.0.1", "", None]:
            self.assertIsNone(guard.kfit_version(tag), tag)

    def test_orders_numerically_not_alphabetically(self):
        self.assertLess(guard.kfit_version("v3.0.99"), guard.kfit_version("v3.0.717"))
        self.assertLess(guard.kfit_version("v3.0.717"), guard.kfit_version("v3.1.0"))


class EnsureTest(unittest.TestCase):
    def test_kfit_latest_is_left_alone(self):
        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="v3.0.717")
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, [])
        self.assertEqual(fake.list_calls, 0)
        self.assertIn("Nothing to do", log)

    def test_older_kfit_latest_is_left_alone_as_a_rollback(self):
        fake = FakeGh([rel("v3.0.717"), rel("v3.0.716")], latest="v3.0.716")
        code, _, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, [])
        self.assertEqual(fake.latest, "v3.0.716")

    def test_jarvis_latest_moves_to_newest_kfit(self):
        fake = FakeGh(
            [jarvis(96), rel("v3.0.99"), rel("v3.0.717"), rel("v3.0.700"), jarvis(95)],
            latest="jarvis-v1.0.96",
        )
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.717"])
        self.assertEqual(fake.latest, "v3.0.717")
        self.assertIn("Latest is now v3.0.717", log)

    def test_no_latest_at_all_gets_newest_kfit(self):
        fake = FakeGh([rel("v3.0.717")], latest=None)
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.717"])
        self.assertIn("(no release)", log)

    def test_skips_drafts_prereleases_missing_apk_and_other_tags(self):
        fake = FakeGh(
            [
                rel("v3.0.900", draft=True),
                rel("v3.0.899", prerelease=True),
                rel("v3.0.898", assets=("kfit.patch", "patch.json")),
                rel("v3.0.897-build-5"),
                rel("kfit-v3.0.896"),
                rel("v3.0.700"),
                jarvis(96),
            ],
            latest="jarvis-v1.0.96",
        )
        code, _, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.700"])

    def test_fails_when_there_is_no_kfit_release(self):
        fake = FakeGh([jarvis(96), jarvis(95), rel("v3.0.5", assets=())], latest="jarvis-v1.0.96")
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertEqual(fake.edits, [])
        self.assertTrue(log.startswith("::error::"), log)
        self.assertIn("no published KFit release", log)

    def test_dry_run_reports_without_editing(self):
        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96")
        code, log, _ = run(fake, dry_run=True)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, [])
        self.assertEqual(fake.latest, "jarvis-v1.0.96")
        self.assertIn("would mark v3.0.717", log)

    def test_follows_a_kfit_release_published_mid_run(self):
        def kfit_publishes_first(fake, tag):
            # KFit's own build publishes v3.0.718 (with --latest) just before
            # our first edit lands, so the edit would demote it.
            if not fake.edits:
                fake.releases.insert(0, rel("v3.0.718"))
                fake.latest = "v3.0.718"

        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96", on_edit=kfit_publishes_first)
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.717", "v3.0.718"])
        self.assertEqual(fake.latest, "v3.0.718")
        self.assertIn("v3.0.718 was published meanwhile", log)

    def test_edit_failure_fails(self):
        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96", fail={"edit"})
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertIn("Marking v3.0.717 as Latest failed", log)

    def test_list_failure_fails(self):
        fake = FakeGh([rel("v3.0.717")], latest="jarvis-v1.0.96", fail={"list"})
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertIn("Listing releases failed", log)

    def test_latest_read_error_is_not_mistaken_for_no_latest(self):
        fake = FakeGh([rel("v3.0.717")], latest="jarvis-v1.0.96", fail={"latest"})
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertEqual(fake.edits, [])
        self.assertIn("HTTP 500", log)

    def test_change_that_never_shows_up_fails_after_retries(self):
        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96", stuck=True)
        code, log, sleeps = run(fake)
        self.assertEqual(code, 1)
        self.assertEqual(len(sleeps), guard.CONFIRM_ATTEMPTS - 1)
        self.assertIn("still reports jarvis-v1.0.96", log)


def load_workflow(name):
    with open(WORKFLOWS / name, encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    # PyYAML reads the bare key `on` as the boolean True.
    data["on"] = data.pop(True, data.get("on"))
    return data


@unittest.skipIf(yaml is None, "PyYAML not installed")
class WorkflowWiringTest(unittest.TestCase):
    def test_jarvis_releases_are_never_marked_latest(self):
        text = (WORKFLOWS / "build_jarvis_apk.yml").read_text(encoding="utf-8")
        self.assertIn("--latest=false", text)
        self.assertIsNone(
            re.search(r"--latest(?!=false)\b", text),
            "build_jarvis_apk.yml must not publish JARVIS releases with --latest",
        )

    def test_build_jarvis_apk_calls_the_guard_after_every_run(self):
        job = load_workflow("build_jarvis_apk.yml")["jobs"]["keep-kfit-latest"]
        self.assertEqual(job["uses"], "./.github/workflows/ensure-kfit-latest.yml")
        self.assertIn("build-and-release", job["needs"])
        self.assertIn("!cancelled()", job["if"])

    def test_guard_workflow_can_be_called_and_run_by_hand(self):
        wf = load_workflow("ensure-kfit-latest.yml")
        for trigger in ("workflow_call", "workflow_dispatch"):
            dry_run = wf["on"][trigger]["inputs"]["dry_run"]
            self.assertEqual(dry_run["type"], "boolean")
            self.assertIs(dry_run["default"], False)
        self.assertEqual(wf["permissions"], {"contents": "write"})

        steps = wf["jobs"]["ensure"]["steps"]
        self.assertEqual(steps[0]["with"]["sparse-checkout"], ".github/scripts")
        run_step = steps[-1]
        self.assertEqual(run_step["env"]["GH_TOKEN"], "${{ github.token }}")
        self.assertIn("python3 .github/scripts/ensure_kfit_latest.py", run_step["run"])
        self.assertTrue((SCRIPTS / "ensure_kfit_latest.py").is_file())


if __name__ == "__main__":
    unittest.main()
