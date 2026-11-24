"""Deterministic, read-only navigation index of tracked Godot source."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".godot", ".cs"}
DECL = re.compile(r"^\s*(?:(?:static|async)\s+)?(func|signal|class_name|class)\s+(\w+)", re.M)
REF = re.compile(r"""["']res://([^"'\r\n]+)["']""")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def inspect_source(data):
    text = data.decode("utf-8-sig")
    symbols = [{"kind": m[1], "name": m[2],
                "line": text.count("\n", 0, m.start(2)) + 1}
               for m in DECL.finditer(text)]
    return symbols, sorted(set("godot-cove/" + m for m in REF.findall(text)))


def build(root):
    revision = git(root, "rev-parse", "HEAD").decode().strip()
    tracked = sorted(set(git(root, "ls-files", "-z", "--", "godot-cove").decode().split("\0")))
    dirty = bool(git(root, "status", "--porcelain", "--untracked-files=all", "--", "godot-cove").strip())
    files = {}
    skipped = []
    for name in tracked:
        if not name or Path(name).suffix.lower() not in EXT:
            continue
        path = root / name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
            skipped.append(name)
            continue
        data = path.read_bytes()
        try:
            symbols, refs = inspect_source(data)
        except UnicodeDecodeError:
            skipped.append(name)
            continue
        files[name] = {"sha256": hashlib.sha256(data).hexdigest(),
                       "symbols": symbols, "references": refs}
    for item in files.values():
        item["references"] = [name for name in item["references"] if name in files]
    return {"schema": 1, "revision": revision, "dirty": dirty,
            "files": files, "skipped": skipped}


def query(index, phrase, limit):
    terms = re.findall(r"\w+", phrase.lower())
    if not terms:
        return []
    hits = []
    for path, item in index["files"].items():
        matches = [s for s in item["symbols"]
                   if any(t in s["name"].lower() for t in terms)]
        score = sum(4 for t in terms if t in path.lower())
        score += sum(3 for t in terms if any(t in s["name"].lower() for s in matches))
        if score:
            hits.append((score, path, matches[:8], item["references"][:5]))
    hits.sort(key=lambda h: (-h[0], h[1]))
    return [{"path": p, "symbols": s, "references": r} for _, p, s, r in hits[:limit]]


def freshness(root, base):
    changed = set(git(root, "diff", "--name-only", "-z", "--no-renames", base, "HEAD").decode().split("\0"))
    advisories = []
    for guide in sorted((root / "docs/systems").glob("*.md")):
        name = guide.relative_to(root).as_posix()
        if name in changed:
            continue
        refs = set(re.findall(r"\]\(\.\./\.\./(godot-cove/[^)]+)\)", guide.read_text(encoding="utf-8")))
        affected = sorted(refs & changed)
        if affected:
            advisories.append({"guide": name, "changed_sources": affected})
    return advisories


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--query")
    parser.add_argument("--limit", type=int, choices=range(1, 21), default=5)
    parser.add_argument("--base", help="Optional baseline commit for advisory review")
    args = parser.parse_args()
    root = args.root.resolve()
    index = build(root)
    if args.base:
        if not re.fullmatch(r"[0-9a-fA-F]{40,64}", args.base):
            parser.error("--base must be a full commit hash")
        index["documentation_advisories"] = freshness(root, args.base)
    if args.query is not None:
        output = {"revision": index["revision"], "dirty": index["dirty"],
                  "matches": query(index, args.query, args.limit)}
    else:
        output = index
    result = json.dumps(output, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(result, encoding="utf-8")
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
