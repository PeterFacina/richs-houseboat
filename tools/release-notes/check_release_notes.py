#!/usr/bin/env python3
"""Require and validate the per-PR player-facing release note."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Sequence


RELEASE_NOTES_DIR = "godot-cove/release-notes/"
NOTE_NAME = re.compile(r"^godot-cove/release-notes/pr-(\d+)\.json$")
MAX_BULLET_CHARS = 450


def reject_json_constant(value: str) -> None:
    raise ValueError(f"{value} is not a JSON value")


def is_player_facing_path(path: str) -> bool:
    """Treat runtime project changes as player-facing, except tests and notes."""
    normalized = path.replace("\\", "/").lstrip("./")
    if not normalized.startswith("godot-cove/"):
        return False
    parts = normalized.split("/")
    if any(part in {".godot", "test", "tests", "testing", "__tests__", "tools"} for part in parts[1:]):
        return False
    source_suffixes = {".gd", ".cs", ".py", ".tscn", ".tres"}
    stem = Path(normalized).stem.lower()
    if Path(normalized).suffix.lower() in source_suffixes and (stem.startswith("test_") or stem.endswith("_test")):
        return False
    if Path(normalized).suffix.lower() in {".md", ".rst", ".txt"}:
        return False
    if normalized.startswith(RELEASE_NOTES_DIR):
        return False
    return True


def validate_note(path: str, pr_number: int, root: Path) -> list[str]:
    errors: list[str] = []
    match = NOTE_NAME.fullmatch(path)
    if not match:
        return [f"Release note must be named {RELEASE_NOTES_DIR}pr-{pr_number}.json (found {path})."]
    filename_pr = int(match.group(1))
    if filename_pr != pr_number:
        errors.append(f"Release-note filename says PR #{filename_pr}, but this is PR #{pr_number}.")

    note_path = root / Path(*path.split("/"))
    try:
        with note_path.open(encoding="utf-8") as note_file:
            note = json.load(note_file, parse_constant=reject_json_constant)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        return errors + [f"Could not read valid JSON from {path}: {exc}."]

    if not isinstance(note, dict):
        return errors + [f"{path} must contain a JSON object."]
    note_pr = note.get("pr")
    if type(note_pr) is not int or note_pr != pr_number:
        errors.append(f"{path}: 'pr' must be the integer {pr_number} for this pull request.")
    if note.get("player_facing") is not True:
        errors.append(f"{path}: 'player_facing' must be true for a gameplay pull request.")
    bullets = note.get("bullets")
    if not isinstance(bullets, list) or not bullets:
        errors.append(f"{path}: 'bullets' must be a non-empty array of player-facing strings.")
    elif any(not isinstance(bullet, str) or not bullet.strip() for bullet in bullets):
        errors.append(f"{path}: every bullet must be a non-empty string.")
    elif sum(len(bullet.strip()) for bullet in bullets) >= MAX_BULLET_CHARS:
        errors.append(f"{path}: release-note bullets must total fewer than {MAX_BULLET_CHARS} characters.")
    return errors


def check_release_notes(changed_paths: Sequence[str], pr_number: int, root: Path) -> list[str]:
    gameplay_paths = [path for path in changed_paths if is_player_facing_path(path)]
    changed_note_paths = [path for path in changed_paths if path.startswith(RELEASE_NOTES_DIR)]
    errors: list[str] = []

    if gameplay_paths:
        expected = f"{RELEASE_NOTES_DIR}pr-{pr_number}.json"
        if expected not in changed_note_paths:
            files = ", ".join(gameplay_paths[:5])
            suffix = " ..." if len(gameplay_paths) > 5 else ""
            errors.append(
                f"Player-facing game files changed ({files}{suffix}), but {expected} is missing. "
                "Add it with pr, player_facing: true, and concise bullets, then push the update."
            )

    if changed_note_paths and not gameplay_paths:
        errors.append("This pull request changes no player-facing game files, so remove its release note.")

    for path in changed_note_paths:
        errors.extend(validate_note(path, pr_number, root))
    return errors


def changed_paths(base: str, head: str, root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMRTUXB", f"{base}...{head}"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="PR base commit SHA")
    parser.add_argument("--head", required=True, help="PR head commit SHA")
    parser.add_argument("--pr", required=True, type=int, help="GitHub pull-request number")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="checked-out repository root")
    args = parser.parse_args(argv)

    try:
        paths = changed_paths(args.base, args.head, args.root)
    except subprocess.CalledProcessError as exc:
        print(f"::error::Could not compare the pull request with its base: {exc.stderr.strip()}")
        return 2

    errors = check_release_notes(paths, args.pr, args.root)
    if errors:
        for error in errors:
            print(f"::error::{error}")
        return 1

    print("Release-note check passed: gameplay changes have a valid PR-specific note, or no note is required.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
