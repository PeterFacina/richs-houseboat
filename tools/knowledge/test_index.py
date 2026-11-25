import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from index import GAME_ROUTES, build, freshness, inspect_source, query


class IndexTest(unittest.TestCase):
    def test_symbols_and_refs(self):
        symbols, refs = inspect_source(b'# header\nstatic func sail():\n  preload("res://swell.gd")\nsignal changed\n')
        self.assertEqual([(s["name"], s["line"]) for s in symbols], [("sail", 2), ("changed", 4)])
        self.assertEqual(refs, ["godot-cove/swell.gd"])

    def test_game_identity_routes(self):
        files = {f"godot-cove/{name}": {"symbols": [], "references": []}
                 for name in ("deep_river_map.gd", "rich_story.gd", "quest_chain.gd",
                              "shannon_job.gd", "progression.gd", "river_stock.gd")}
        index = {"files": files}
        for phrase, expected in (
            ("Deep River world map", "deep_river_map.gd"),
            ("res://ottawa_map.gd", "deep_river_map.gd"),
            ("Big Rich questline", "rich_story.gd"),
            ("Shared quest framework", "quest_chain.gd"),
            ("Future Shannon Lapping questline", "shannon_job.gd"),
            ("Future research tree architecture", "progression.gd"),
            ("Ottawa River fish populations", "river_stock.gd"),
        ):
            with self.subTest(phrase=phrase):
                self.assertEqual(query(index, phrase, 1)[0]["path"], f"godot-cove/{expected}")

    def test_current_godot_paths_use_canonical_names(self):
        project = Path(__file__).resolve().parents[2] / "godot-cove"
        obsolete = re.compile(r"res://ottawa/|(?<![\w.-])(?:" + "|".join(
            re.escape(name) for name in GAME_ROUTES["aliases"]) + r")(?![\w.-])")
        for path in project.iterdir():
            if path.is_file() and path.suffix in {".gd", ".tscn", ".tres", ".cfg", ".godot"}:
                self.assertIsNone(obsolete.search(path.read_text(encoding="utf-8-sig")), str(path))
        self.assertFalse((project / "ottawa").exists())

    def test_real_repository(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()

            def git(*args):
                return subprocess.check_output(["git", "-C", tmp, *args], stderr=subprocess.STDOUT).decode().strip()

            git("init")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            (root / "godot-cove").mkdir()
            (root / "docs/systems").mkdir(parents=True)
            boat = root / "godot-cove/boat.gd"
            boat.write_text('func sail():\n  preload("res://swell.gd")\n', encoding="utf-8")
            (root / "godot-cove/swell.gd").write_text("class_name Swell\n", encoding="utf-8")
            guide = root / "docs/systems/BOAT.md"
            guide.write_text("[Boat](../../godot-cove/boat.gd)\n", encoding="utf-8")
            git("add", ".")
            git("commit", "-m", "fixture")
            base = git("rev-parse", "HEAD")
            first = build(root)
            self.assertFalse(first["dirty"])
            self.assertEqual(first, build(root))
            self.assertEqual(query(first, "sail", 1)[0]["path"], "godot-cove/boat.gd")
            self.assertEqual(first["files"]["godot-cove/boat.gd"]["references"], ["godot-cove/swell.gd"])
            boat.write_text("func drift():\n  pass\n", encoding="utf-8")
            self.assertTrue(build(root)["dirty"])
            git("add", ".")
            git("commit", "-m", "change boat")
            self.assertEqual(freshness(root, base), [{"guide": "docs/systems/BOAT.md", "changed_sources": ["godot-cove/boat.gd"]}])
            guide.write_text("Updated [Boat](../../godot-cove/boat.gd)\n", encoding="utf-8")
            git("add", ".")
            git("commit", "-m", "update guide")
            self.assertEqual(freshness(root, base), [])


if __name__ == "__main__":
    unittest.main()
