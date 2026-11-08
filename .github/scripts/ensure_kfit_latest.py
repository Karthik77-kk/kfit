#!/usr/bin/env python3
"""Keep this repository's "Latest" release on a KFit release.

Two apps publish releases to Karthik77-kk/kfit:

  * KFit:   v3.0.N         (build_apk.yml, published with --latest)
  * JARVIS: jarvis-v1.0.N  (build_jarvis_apk.yml, published with --latest=false)

/releases/latest has to be a KFit release carrying kfit.apk. The website
download links (/releases/latest/download/kfit.apk) and KFit's background
updater (KFitUpdateJobService) both follow it. Anywhere else, the download link
returns 404 and KFit silently stops downloading updates in the background.

What this does:

  * Latest is a KFit release with an uploaded kfit.apk: nothing. That includes
    an OLDER KFit release, because someone may have marked it on purpose to
    roll back a bad build.
  * Latest is not a KFit release (a JARVIS release, or nothing at all): mark the
    newest published KFit release with an uploaded kfit.apk as Latest, then
    confirm it took.
  * Latest is a KFit release WITHOUT kfit.apk: report it and fail, but do not
    move Latest. kfit.apk may be mid re-upload (it is ~200 MB), and moving
    Latest to an older build would then stick, because of the rule above.
  * There is no KFit release to point Latest at: fail.

To roll back KFit, mark the bad release as a pre-release (or delete it) as well
as marking the good one Latest. This never picks a pre-release, so a later
repair cannot bring the bad build back.

Exit code 0 means Latest is (now) a KFit release with kfit.apk, or this was a
dry run that found nothing it could not fix. Exit code 1 means it is not.

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
from typing import Callable, List, NamedTuple, Optional, Sequence, Tuple

# The tag shape build_apk.yml publishes: TAG="v${NAME%.*}.${CODE}", e.g. v3.0.717.
KFIT_TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
KFIT_ASSET = "kfit.apk"
# Assets whose upload has not finished (state "open"/"starter") cannot be downloaded.
UPLOADED = "uploaded"

# One compact JSON object per release, one per line, listing only finished
# uploads. Parsing lines keeps this independent of the gh version (no --slurp).
RELEASES_JQ = (
    ".[] | {tag_name, draft, prerelease, "
    'assets: [.assets[] | select(.state == "uploaded") | .name]}'
)

# A KFit Latest without kfit.apk may be mid re-upload; look again after this.
ASSET_RECHECK_SECONDS = 15
# Times to re-list after marking, in case a KFit release is published mid-run.
RACE_RECHECKS = 3
# Times to read Latest back before giving up on the change showing.
CONFIRM_ATTEMPTS = 5
CONFIRM_DELAY_SECONDS = 2

GhResult = Tuple[int, str, str]
Gh = Callable[[Sequence[str]], GhResult]


class Release(NamedTuple):
    tag: str
    assets: Tuple[str, ...]  # names of fully uploaded assets


class GhError(RuntimeError):
    """A gh call failed, or returned something this script cannot read."""


def run_gh(args: Sequence[str]) -> GhResult:
    try:
        proc = subprocess.run(["gh", *args], capture_output=True, text=True)
    except OSError as exc:  # gh not installed or not runnable
        return 127, "", str(exc)
    return proc.returncode, proc.stdout, proc.stderr


def kfit_version(tag: Optional[str]) -> Optional[Tuple[int, int, int]]:
    """(3, 0, 717) for "v3.0.717"; None for anything that is not a KFit tag."""
    match = KFIT_TAG.match(tag or "")
    if not match:
        return None
    major, minor, build = (int(part) for part in match.groups())
    return major, minor, build


def serves_kfit(release: Optional[Release]) -> bool:
    """True when /releases/latest/download/kfit.apk would work for this release."""
    return bool(release and kfit_version(release.tag) and KFIT_ASSET in release.assets)


def describe(release: Optional[Release]) -> str:
    if release is None:
        return "(no release)"
    if kfit_version(release.tag) and KFIT_ASSET not in release.assets:
        return f"{release.tag} (a KFit release without an uploaded {KFIT_ASSET})"
    return release.tag


def _json(text: str, what: str):
    try:
        return json.loads(text)
    except ValueError as exc:
        raise GhError(f"{what} returned something that is not JSON: {exc}") from exc


def latest_release(gh: Gh, repo: str) -> Optional[Release]:
    """The release GitHub currently reports as Latest, or None if none is."""
    code, out, err = gh(["api", f"repos/{repo}/releases/latest"])
    if code != 0:
        if "HTTP 404" in err:
            return None
        raise GhError(f"Reading the Latest release failed: {err.strip() or 'exit ' + str(code)}")
    data = _json(out, "Reading the Latest release")
    if not isinstance(data, dict):
        raise GhError("Reading the Latest release returned an unexpected shape.")
    tag = data.get("tag_name") or ""
    assets = tuple(
        asset.get("name", "")
        for asset in data.get("assets") or []
        if isinstance(asset, dict) and asset.get("state") == UPLOADED
    )
    return Release(tag, assets) if tag else None


def newest_kfit_release(gh: Gh, repo: str) -> Optional[str]:
    """Highest-versioned published KFit release with an uploaded kfit.apk, or None."""
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
        release = _json(line, "Listing releases")
        if not isinstance(release, dict):
            raise GhError("Listing releases returned an unexpected shape.")
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
        current = latest_release(gh, repo)
        if current and kfit_version(current.tag) and not serves_kfit(current):
            log(f"Latest is {describe(current)}. Checking again in {ASSET_RECHECK_SECONDS}s.")
            sleep(ASSET_RECHECK_SECONDS)
            current = latest_release(gh, repo)

        if serves_kfit(current):
            log(f"Latest is {current.tag}, a KFit release with {KFIT_ASSET}. Nothing to do.")
            return 0

        shown = describe(current)
        if current and kfit_version(current.tag):
            # Not moved automatically: see the module docstring.
            log(
                f"::error::Latest is {shown}, so the KFit download link returns 404. Not moving "
                f"Latest automatically: re-upload {KFIT_ASSET} to {current.tag}, or mark another "
                "KFit release as Latest."
            )
            return 1

        target = newest_kfit_release(gh, repo)
        if not target:
            log(
                f"::error::Latest is {shown}, and there is no published KFit release with "
                f"{KFIT_ASSET} to mark as Latest. The KFit download link stays broken until "
                "a KFit release is published."
            )
            return 1

        if dry_run:
            log(f"::warning::Latest is {shown}, which breaks the KFit download link. Dry run: would mark {target} as Latest.")
            return 0

        log(f"Latest is {shown}, which breaks the KFit download link. Marking {target} as Latest.")
        # A KFit release published between a listing and an edit is newer than
        # target, and the edit takes Latest away from it. After every edit,
        # list again; follow a newer release, or stop once nothing newer shows.
        for attempt in range(RACE_RECHECKS + 1):
            mark_latest(gh, repo, target)
            newer = newest_kfit_release(gh, repo)
            if not newer or newer == target:
                break
            if attempt == RACE_RECHECKS:
                log(
                    f"::error::KFit releases kept appearing while Latest was being repaired. "
                    f"Marked {target}, but {newer} is newer. Run this workflow again."
                )
                return 1
            log(f"{newer} was published meanwhile. Marking it instead.")
            target = newer

        final: Optional[Release] = None
        for attempt in range(CONFIRM_ATTEMPTS):
            final = latest_release(gh, repo)
            if serves_kfit(final):
                log(f"Latest is now {final.tag}.")
                return 0
            if attempt < CONFIRM_ATTEMPTS - 1:
                sleep(CONFIRM_DELAY_SECONDS)

        log(f"::error::Marked {target} as Latest, but GitHub still reports {describe(final)}.")
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
