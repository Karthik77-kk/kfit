#!/usr/bin/env python3
"""Keep this repository's "Latest" release on a KFit release.

Two apps publish releases to Karthik77-kk/kfit:

  * KFit:   v3.0.N         (build_apk.yml, published with --latest)
  * JARVIS: jarvis-v1.0.N  (build_jarvis_apk.yml, published with --latest=false)

/releases/latest has to be a KFit release. The website download links
(/releases/latest/download/kfit.apk) and KFit's background updater
(KFitUpdateJobService) both follow it. When it lands on a JARVIS release, the
download link returns 404 and KFit silently stops downloading updates in the
background.

What this does:

  * Latest is a KFit release: nothing. That includes an OLDER KFit release,
    because someone may have marked it on purpose to roll back a bad build.
  * Latest is anything else, or nothing is Latest: mark the newest published
    KFit release that carries kfit.apk as Latest, then confirm it took.
  * There is no such KFit release: fail, because there is nothing safe to
    point Latest at.

Exit code 0 means Latest is (now) a KFit release, or this was a dry run.
Exit code 1 means it could not make sure of that.

Usage: ensure_kfit_latest.py [--repo OWNER/NAME] [--dry-run]
Needs the gh CLI, authenticated with contents:write on the repository.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from typing import Callable, List, Optional, Sequence, Tuple

KFIT_TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
KFIT_ASSET = "kfit.apk"

# One compact JSON object per release, one per line. Parsing lines keeps this
# independent of the gh version (no --slurp needed).
RELEASES_JQ = ".[] | {tag_name, draft, prerelease, assets: [.assets[].name]}"

# Times to re-list after marking, in case a KFit release is published mid-run.
RACE_RECHECKS = 3
# Times to read Latest back before giving up on the change showing.
CONFIRM_ATTEMPTS = 5
CONFIRM_DELAY_SECONDS = 2

GhResult = Tuple[int, str, str]
Gh = Callable[[Sequence[str]], GhResult]


class GhError(RuntimeError):
    """A gh call failed in a way this script cannot work around."""


def run_gh(args: Sequence[str]) -> GhResult:
    try:
        proc = subprocess.run(["gh", *args], capture_output=True, text=True)
    except OSError as exc:  # gh not installed or not runnable
        return 127, "", str(exc)
    return proc.returncode, proc.stdout, proc.stderr


def kfit_version(tag: str) -> Optional[Tuple[int, int, int]]:
    """(3, 0, 717) for "v3.0.717"; None for anything that is not a KFit tag."""
    match = KFIT_TAG.match(tag or "")
    if not match:
        return None
    major, minor, build = (int(part) for part in match.groups())
    return major, minor, build


def latest_tag(gh: Gh, repo: str) -> Optional[str]:
    """Tag of the release GitHub currently reports as Latest, or None if none is."""
    code, out, err = gh(["api", f"repos/{repo}/releases/latest"])
    if code != 0:
        if "HTTP 404" in err:
            return None
        raise GhError(f"Reading the Latest release failed: {err.strip() or 'exit ' + str(code)}")
    return json.loads(out).get("tag_name") or None


def newest_kfit_release(gh: Gh, repo: str) -> Optional[str]:
    """Highest-versioned published KFit release that carries kfit.apk, or None."""
    code, out, err = gh(
        ["api", f"repos/{repo}/releases?per_page=100", "--paginate", "--jq", RELEASES_JQ]
    )
    if code != 0:
        raise GhError(f"Listing releases failed: {err.strip() or 'exit ' + str(code)}")

    best: Optional[Tuple[Tuple[int, int, int], str]] = None
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        release = json.loads(line)
        if release.get("draft") or release.get("prerelease"):
            continue  # GitHub never lets these be Latest
        tag = release.get("tag_name") or ""
        version = kfit_version(tag)
        if version is None:
            continue
        if KFIT_ASSET not in (release.get("assets") or []):
            continue  # the download link would still 404
        if best is None or version > best[0]:
            best = (version, tag)
    return best[1] if best else None


def mark_latest(gh: Gh, repo: str, tag: str) -> None:
    code, _, err = gh(["release", "edit", tag, "--repo", repo, "--latest"])
    if code != 0:
        raise GhError(f"Marking {tag} as Latest failed: {err.strip() or 'exit ' + str(code)}")


def ensure(
    gh: Gh,
    repo: str,
    dry_run: bool = False,
    log: Callable[[str], None] = print,
    sleep: Callable[[float], None] = time.sleep,
) -> int:
    try:
        current = latest_tag(gh, repo)
        if current and kfit_version(current):
            log(f"Latest is {current}, a KFit release. Nothing to do.")
            return 0

        shown = current or "(no release)"
        target = newest_kfit_release(gh, repo)
        if not target:
            log(
                f"::error::Latest is {shown}, and there is no published KFit release with "
                f"{KFIT_ASSET} to mark as Latest. The KFit download link stays broken until "
                "a KFit release is published."
            )
            return 1

        if dry_run:
            log(f"::warning::Latest is {shown}, not a KFit release. Dry run: would mark {target} as Latest.")
            return 0

        log(f"Latest is {shown}, not a KFit release. Marking {target} as Latest.")
        # A KFit release published between the listing and the edit is newer than
        # target, and the edit would take Latest away from it. Re-list after each
        # edit and follow the newest one.
        for _ in range(RACE_RECHECKS):
            mark_latest(gh, repo, target)
            newer = newest_kfit_release(gh, repo)
            if not newer or newer == target:
                break
            log(f"{newer} was published meanwhile. Marking it instead.")
            target = newer

        final: Optional[str] = None
        for attempt in range(CONFIRM_ATTEMPTS):
            final = latest_tag(gh, repo)
            if final and kfit_version(final):
                log(f"Latest is now {final}.")
                return 0
            if attempt < CONFIRM_ATTEMPTS - 1:
                sleep(CONFIRM_DELAY_SECONDS)

        log(f"::error::Marked {target} as Latest, but GitHub still reports {final or '(no release)'}.")
        return 1
    except GhError as exc:
        log(f"::error::{exc}")
        return 1


def _strip_annotation(message: str) -> str:
    return re.sub(r"^::\w+::", "", message)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Keep the repository's Latest release on a KFit release.")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""), help="OWNER/NAME")
    parser.add_argument("--dry-run", action="store_true", help="only report what would change")
    args = parser.parse_args(argv)
    if not args.repo:
        parser.error("--repo is required when GITHUB_REPOSITORY is not set")

    lines: List[str] = []

    def log(message: str) -> None:
        print(message, flush=True)
        lines.append(message)

    code = ensure(run_gh, args.repo, dry_run=args.dry_run, log=log)

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as summary:
            summary.write("### Keep KFit release as Latest\n\n")
            for line in lines:
                summary.write(f"- {_strip_annotation(line)}\n")
    return code


if __name__ == "__main__":
    sys.exit(main())
