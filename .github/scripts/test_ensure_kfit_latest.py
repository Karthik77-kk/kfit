"""Tests for ensure_kfit_latest.py and the workflows that wire it in.

Run: python3 -m unittest discover -s .github/scripts -p 'test_*.py' -v
"""

from __future__ import annotations

import importlib.util
import json
import os
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
except ImportError:
    # In CI the workflow checks below must run, not skip: fail loudly there.
    if os.environ.get("GITHUB_ACTIONS") == "true":
        raise
    yaml = None

REPO = "owner/kfit"


def rel(tag, assets=("kfit.apk",), draft=False, prerelease=False, uploading=()):
    """A release. `assets` are fully uploaded; `uploading` are still in state "open"."""
    return {
        "tag_name": tag,
        "draft": draft,
        "prerelease": prerelease,
        "assets": list(assets),
        "uploading": list(uploading),
    }


def jarvis(build):
    return rel(f"jarvis-v1.0.{build}", assets=("jarvis.apk", "jarvis.apk.sha256"))


class FakeGh:
    """Stands in for the gh CLI: answers the three calls the guard makes."""

    def __init__(self, releases, latest, fail=(), on_edit=None, on_latest=None, stuck=False):
        self.releases = list(releases)
        self.latest = latest
        self.fail = set(fail)  # any of "latest", "list", "edit", "latest-garbage", "list-garbage"
        self.on_edit = on_edit  # called before an edit lands
        self.on_latest = on_latest  # called before each Latest read
        self.stuck = stuck  # edits "succeed" but Latest never changes
        self.edits = []
        self.list_calls = 0
        self.latest_reads = 0

    def release(self, tag):
        return next((r for r in self.releases if r["tag_name"] == tag), None)

    def __call__(self, args):
        args = list(args)
        if args == ["api", f"repos/{REPO}/releases/latest"]:
            self.latest_reads += 1
            if self.on_latest:
                self.on_latest(self)
            if "latest" in self.fail:
                return 1, "", "gh: Server Error (HTTP 500)"
            if "latest-garbage" in self.fail:
                return 0, "<html>502 Bad Gateway</html>", ""
            if self.latest is None:
                return 1, '{"message":"Not Found","status":"404"}', "gh: Not Found (HTTP 404)"
            found = self.release(self.latest) or {"assets": [], "uploading": []}
            assets = [{"name": n, "state": "uploaded"} for n in found["assets"]]
            assets += [{"name": n, "state": "open"} for n in found["uploading"]]
            return 0, json.dumps({"tag_name": self.latest, "assets": assets}), ""
        if args == ["api", f"repos/{REPO}/releases?per_page=100", "--paginate", "--jq", guard.RELEASES_JQ]:
            self.list_calls += 1
            if "list" in self.fail:
                return 1, "", "gh: Bad credentials (HTTP 401)"
            if "list-garbage" in self.fail:
                return 0, '{"tag_name": "v3.0.7\n', ""
            # What RELEASES_JQ emits: one object per release, finished uploads only.
            lines = [
                {k: r[k] for k in ("tag_name", "draft", "prerelease")} | {"assets": r["assets"]}
                for r in self.releases
            ]
            return 0, "".join(json.dumps(line) + "\n" for line in lines), ""
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
        code, log, sleeps = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, [])
        self.assertEqual(fake.list_calls, 0)
        self.assertEqual(sleeps, [])
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
        code, log, sleeps = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.717"])
        self.assertEqual(fake.latest, "v3.0.717")
        self.assertEqual(sleeps, [])  # no asset re-check for a JARVIS Latest
        self.assertIn("Latest is now v3.0.717", log)

    def test_no_latest_at_all_gets_newest_kfit(self):
        fake = FakeGh([rel("v3.0.717")], latest=None)
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.717"])
        self.assertIn("(no release)", log)

    def test_kfit_latest_without_kfit_apk_fails_but_is_not_moved(self):
        # Moving Latest to v3.0.717 would stick (older KFit Latest = rollback),
        # even after kfit.apk finishes re-uploading to v3.0.718.
        fake = FakeGh(
            [rel("v3.0.718", assets=("kfit.patch", "patch.json")), rel("v3.0.717"), jarvis(96)],
            latest="v3.0.718",
        )
        code, log, sleeps = run(fake)
        self.assertEqual(code, 1)
        self.assertEqual(fake.edits, [])
        self.assertEqual(fake.latest, "v3.0.718")
        self.assertEqual(sleeps, [guard.ASSET_RECHECK_SECONDS])
        self.assertIn("::error::Latest is v3.0.718 (a KFit release without an uploaded kfit.apk)", log)
        self.assertIn("Not moving Latest automatically", log)

    def test_kfit_apk_still_uploading_counts_as_missing(self):
        fake = FakeGh(
            [rel("v3.0.718", assets=(), uploading=("kfit.apk",)), rel("v3.0.717")],
            latest="v3.0.718",
        )
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertEqual(fake.edits, [])
        self.assertIn("without an uploaded kfit.apk", log)

    def test_dry_run_reports_a_kfit_latest_without_kfit_apk_as_a_failure(self):
        fake = FakeGh([rel("v3.0.718", assets=()), rel("v3.0.717")], latest="v3.0.718")
        code, log, _ = run(fake, dry_run=True)
        self.assertEqual(code, 1)
        self.assertEqual(fake.edits, [])
        self.assertIn("::error::", log)

    def test_kfit_apk_that_reappears_on_recheck_is_left_alone(self):
        def upload_finishes(fake):
            if fake.latest_reads == 2:
                fake.release("v3.0.718")["assets"] = ["kfit.apk"]

        fake = FakeGh(
            [rel("v3.0.718", assets=()), rel("v3.0.717")],
            latest="v3.0.718",
            on_latest=upload_finishes,
        )
        code, log, sleeps = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, [])
        self.assertEqual(fake.latest, "v3.0.718")
        self.assertEqual(sleeps, [guard.ASSET_RECHECK_SECONDS])
        self.assertIn("Nothing to do", log)

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
            # our first edit lands, so the edit demotes it.
            if not fake.edits:
                fake.releases.insert(0, rel("v3.0.718"))
                fake.latest = "v3.0.718"

        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96", on_edit=kfit_publishes_first)
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(fake.edits, ["v3.0.717", "v3.0.718"])
        self.assertEqual(fake.latest, "v3.0.718")
        self.assertIn("v3.0.718 was published meanwhile", log)

    def test_race_that_never_settles_fails_and_marks_every_release_it_switched_to(self):
        def kfit_keeps_publishing(fake, tag):
            newest = max(guard.kfit_version(r["tag_name"])[2] for r in fake.releases if guard.kfit_version(r["tag_name"]))
            fake.releases.insert(0, rel(f"v3.0.{newest + 1}"))

        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96", on_edit=kfit_keeps_publishing)
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        switched = re.findall(r"(v3\.0\.\d+) was published meanwhile", log)
        self.assertEqual(len(switched), guard.RACE_RECHECKS)
        # The initial target plus every release it said it switched to was marked...
        self.assertEqual(fake.edits, ["v3.0.717", *switched])
        # ...and it does not claim success while a newer KFit release exists.
        self.assertIn("kept appearing", log)
        self.assertNotIn("Latest is now", log)

    def test_race_that_settles_on_the_last_recheck_succeeds(self):
        def kfit_publishes_a_few(fake, tag):
            if len(fake.edits) < guard.RACE_RECHECKS:
                newest = max(guard.kfit_version(r["tag_name"])[2] for r in fake.releases if guard.kfit_version(r["tag_name"]))
                fake.releases.insert(0, rel(f"v3.0.{newest + 1}"))

        fake = FakeGh([jarvis(96), rel("v3.0.717")], latest="jarvis-v1.0.96", on_edit=kfit_publishes_a_few)
        code, log, _ = run(fake)
        self.assertEqual(code, 0)
        self.assertEqual(len(fake.edits), guard.RACE_RECHECKS + 1)
        self.assertEqual(fake.latest, fake.edits[-1])
        self.assertIn(f"Latest is now {fake.edits[-1]}", log)

    def test_malformed_latest_response_fails_cleanly(self):
        fake = FakeGh([rel("v3.0.717")], latest="v3.0.717", fail={"latest-garbage"})
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertIn("::error::Reading the Latest release returned something that is not JSON", log)

    def test_malformed_release_listing_fails_cleanly(self):
        fake = FakeGh([rel("v3.0.717")], latest="jarvis-v1.0.96", fail={"list-garbage"})
        code, log, _ = run(fake)
        self.assertEqual(code, 1)
        self.assertEqual(fake.edits, [])
        self.assertIn("::error::Listing releases returned something that is not JSON", log)

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
        self.assertEqual(sleeps, [guard.CONFIRM_DELAY_SECONDS] * (guard.CONFIRM_ATTEMPTS - 1))
        self.assertIn("still reports jarvis-v1.0.96", log)


def load_workflow(name):
    with open(WORKFLOWS / name, encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    # PyYAML reads the bare key `on` as the boolean True.
    data["on"] = data.pop(True, data.get("on"))
    return data


def run_scripts(workflow):
    return [step["run"] for job in workflow["jobs"].values() for step in job.get("steps", []) if "run" in step]


def shell_commands(script, command):
    """Every occurrence of `command` in a shell script, with its continuation lines."""
    found = []
    for match in re.finditer(re.escape(command), script):
        lines = []
        for line in script[match.start():].split("\n"):
            lines.append(line)
            if not line.rstrip().endswith("\\"):
                break
        found.append("\n".join(lines))
    return found


@unittest.skipIf(yaml is None, "PyYAML not installed")
class WorkflowWiringTest(unittest.TestCase):
    def test_every_jarvis_release_create_passes_latest_false(self):
        scripts = run_scripts(load_workflow("build_jarvis_apk.yml"))
        creates = [cmd for script in scripts for cmd in shell_commands(script, "gh release create")]
        self.assertTrue(creates, "build_jarvis_apk.yml no longer creates releases?")
        for cmd in creates:
            self.assertIn("--latest=false", cmd, cmd)
            self.assertIsNone(re.search(r"--latest(?!=false)\b", cmd), cmd)

    def test_jarvis_workflow_never_marks_anything_latest_another_way(self):
        joined = "\n".join(run_scripts(load_workflow("build_jarvis_apk.yml")))
        self.assertNotIn("make_latest", joined)
        for cmd in shell_commands(joined, "gh release edit"):
            self.assertNotIn("--latest", cmd, cmd)

    def test_build_jarvis_apk_calls_the_guard_after_a_publish(self):
        job = load_workflow("build_jarvis_apk.yml")["jobs"]["keep-kfit-latest"]
        self.assertEqual(job["uses"], "./.github/workflows/ensure-kfit-latest.yml")
        self.assertIn("build-and-release", job["needs"])
        self.assertIn("!cancelled()", job["if"])
        self.assertIn("needs.detect.outputs.build == 'true'", job["if"])

    def test_guard_workflow_runs_on_a_schedule_when_called_and_by_hand(self):
        wf = load_workflow("ensure-kfit-latest.yml")
        self.assertTrue(wf["on"]["schedule"][0]["cron"])
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
