import tempfile
import unittest
from pathlib import Path
from retrieve import functions, retrieve, bounded
from github_context import summarize, select_patches, pages


class RetrievalTest(unittest.TestCase):
    def test_nested_multiline_and_budget(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = "godot-cove/boat.gd"
            (root / "godot-cove").mkdir()
            (root / path).write_text(
                'func drift(\n    delta: float\n):\n    pass\n\n'
                'func sail():\n    drift(1.0)\n    # drift(2.0)\n'
                '    print("drift(3.0)")\nclass Inner:\n    func drift():\n        pass\n',
                encoding="utf-8")
            catalog = {"revision": "fixture", "dirty": False, "files": {path: {}}}
            result = retrieve(root, catalog, "drift", budget=1024)
            self.assertEqual(len(result["definitions"]), 2)
            self.assertEqual(result["definitions"][0]["function_end"], 4)
            self.assertEqual(len(result["lexical_calls"]), 1)
            self.assertEqual(result["lexical_calls"][0]["function"], "sail")
            self.assertTrue(bounded(result, 1024))
            partial = retrieve(root, catalog, "drift", max_lines=1)
            self.assertTrue(partial["definitions"][0]["partial"])

    def test_github_metadata(self):
        rows = [{"number": 1, "title": "Boat drift", "body": "water", "draft": True},
                {"number": 2, "title": "Mowing"}]
        self.assertEqual(summarize(rows, "drift", 1)["matches"][0]["number"], 1)
        patches = [{"filename": "boat.gd", "patch": "x" * 2000}, {"filename": "other.gd"}]
        self.assertTrue(select_patches(patches, ["boat.gd"], 1024)["truncated"])
        self.assertEqual(select_patches(patches, [], 1024)["files"][0]["path"], "boat.gd")
        self.assertEqual(list(pages("/issues", fetch=lambda _: rows)), rows)


if __name__ == "__main__":
    unittest.main()
