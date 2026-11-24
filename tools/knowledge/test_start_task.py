import subprocess
import tempfile
import unittest
from pathlib import Path
from start_task import bootstrap, guides, keywords, live


class BootstrapTest(unittest.TestCase):
    def test_routing(self):
        self.assertIn("docs/systems/BOAT-WATER.md", guides(keywords("Investigate houseboat water drift when nobody controls the helm")))
        self.assertEqual(keywords("the and please"), [])

    def test_live_failure(self):
        def failure(_):
            raise OSError("network unavailable")
        self.assertEqual(live("boat", failure)["status"], "failed")

    def test_local_and_live(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            def git(*args):
                return subprocess.check_output(["git", "-C", tmp, *args], stderr=subprocess.STDOUT)
            git("init")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            (root / "godot-cove").mkdir()
            (root / "godot-cove/boat.gd").write_text("func drift():\n    pass\n", encoding="utf-8")
            git("add", ".")
            git("commit", "-m", "fixture")
            def fixture(route):
                if route.startswith("/issues"):
                    return [{"number": 56, "title": "Boat drift"}, {"number": 57, "title": "Boat drift PR", "pull_request": {}}]
                return [{"number": 57, "title": "Boat drift PR", "draft": True}]
            result = bootstrap(root, "boat drift", fixture)
            self.assertFalse(result["worktree_dirty"])
            self.assertEqual(result["source_matches"][0]["symbols"][0]["name"], "drift")
            self.assertEqual(result["github"]["issues"]["total_matches"], 1)
            self.assertTrue(result["github"]["pulls"]["matches"][0]["draft"])
            self.assertEqual(bootstrap(root, "boat drift", offline=True)["github"]["status"], "skipped")
            (root / "untracked.txt").write_text("test")
            self.assertTrue(bootstrap(root, "boat drift", offline=True)["worktree_dirty"])


if __name__ == "__main__":
    unittest.main()
