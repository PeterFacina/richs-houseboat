from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from check_release_notes import check_release_notes, is_player_facing_path


class ReleaseNoteCheckTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        (self.root / "godot-cove/release-notes").mkdir(parents=True)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def write_note(self, pr: int, note: object, *, filename_pr: int | None = None) -> str:
        filename = filename_pr if filename_pr is not None else pr
        path = f"godot-cove/release-notes/pr-{filename}.json"
        (self.root / path).write_text(json.dumps(note), encoding="utf-8")
        return path

    def valid_note(self, pr: int = 123) -> dict[str, object]:
        return {"pr": pr, "player_facing": True, "bullets": ["Added river cargo work."]}

    def test_valid_player_facing_change_passes(self) -> None:
        path = self.write_note(123, self.valid_note())
        self.assertEqual(check_release_notes(["godot-cove/job_board.gd", path], 123, self.root), [])

    def test_missing_note_fails_with_actionable_message(self) -> None:
        errors = check_release_notes(["godot-cove/job_board.gd"], 123, self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("godot-cove/release-notes/pr-123.json is missing", errors[0])

    def test_malformed_json_fails(self) -> None:
        path = "godot-cove/release-notes/pr-123.json"
        (self.root / path).write_text("{broken", encoding="utf-8")
        errors = check_release_notes(["godot-cove/job_board.gd", path], 123, self.root)
        self.assertTrue(any("Could not read valid JSON" in error for error in errors))

    def test_non_standard_json_constant_fails(self) -> None:
        path = "godot-cove/release-notes/pr-123.json"
        (self.root / path).write_text('{"pr": 123, "player_facing": true, "bullets": ["ok"], "x": NaN}', encoding="utf-8")
        errors = check_release_notes(["godot-cove/job_board.gd", path], 123, self.root)
        self.assertTrue(any("Could not read valid JSON" in error for error in errors))

    def test_wrong_number_and_missing_fields_fail(self) -> None:
        note = {"pr": 122, "player_facing": False, "bullets": []}
        path = self.write_note(123, note)
        errors = check_release_notes(["godot-cove/job_board.gd", path], 123, self.root)
        self.assertTrue(any("'pr' must be the integer 123" in error for error in errors))
        self.assertTrue(any("'player_facing' must be true" in error for error in errors))
        self.assertTrue(any("'bullets' must be a non-empty array" in error for error in errors))

    def test_oversized_note_fails(self) -> None:
        note = self.valid_note()
        note["bullets"] = ["x" * 450]
        path = self.write_note(123, note)
        errors = check_release_notes(["godot-cove/job_board.gd", path], 123, self.root)
        self.assertTrue(any("fewer than 450 characters" in error for error in errors))

    def test_infrastructure_documentation_and_tests_are_excluded(self) -> None:
        for path in (
            ".github/workflows/release-notes.yml",
            "docs/TEAM-WORKFLOW.md",
            "godot-cove/GAME GUIDE AND ASSET CREDITS.md",
            "godot-cove/deep_river/tv/README.txt",
            "godot-cove/tests/job_board_test.gd",
            "godot-cove/job_board_test.gd",
            "godot-cove/tools/release_note_helper.py",
            "godot-cove/.godot/editor/project_metadata.cfg",
            "tools/release-notes/check_release_notes.py",
        ):
            with self.subTest(path=path):
                self.assertFalse(is_player_facing_path(path))
        self.assertEqual(check_release_notes(["docs/TEAM-WORKFLOW.md", ".github/workflows/release-notes.yml"], 123, self.root), [])

    def test_notes_do_not_satisfy_a_different_pr_number(self) -> None:
        path = self.write_note(122, self.valid_note(122))
        errors = check_release_notes(["godot-cove/job_board.gd", path], 123, self.root)
        self.assertTrue(any("pr-123.json is missing" in error for error in errors))
        self.assertTrue(any("filename says PR #122" in error for error in errors))

    def test_infrastructure_only_pr_cannot_add_release_note(self) -> None:
        path = self.write_note(123, self.valid_note())
        errors = check_release_notes(["docs/TEAM-WORKFLOW.md", path], 123, self.root)
        self.assertTrue(any("changes no player-facing game files" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
