import subprocess
import tempfile
import unittest
from pathlib import Path

from index import build, freshness, inspect_source, query


class IndexTest(unittest.TestCase):
    def test_symbols_and_refs(self):
        symbols, refs = inspect_source(b'# header\nstatic func sail():\n  preload("res://swell.gd")\nsignal changed\n')
        self.assertEqual([(s["name"], s["line"]) for s in symbols], [("sail", 2), ("changed", 4)])
        self.assertEqual(refs, ["godot-cove/swell.gd"])

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
