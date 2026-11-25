"""Bounded, local source excerpts and lexical caller hints; not a GDScript parser."""
import argparse
import json
import re
from pathlib import Path
from index import GAME_ROUTES, build

FUNC = re.compile(r"^([ \t]*)(?:(?:static|async)[ \t]+)?func[ \t]+(\w+)\s*\(")
TOKEN = re.compile(r"""(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|#.*$)""")


def clean(line):
    return TOKEN.sub(lambda m: " " * len(m[0]), line)


def indent(line):
    return len(line.expandtabs(4)) - len(line.expandtabs(4).lstrip())


def functions(lines):
    for i, line in enumerate(lines):
        match = FUNC.match(line)
        if not match:
            continue
        depth = indent(line)
        # Multiline declarations can contain unindented closing delimiters.
        j = i
        balance = 0
        while j < len(lines):
            code = clean(lines[j])
            balance += code.count("(") - code.count(")")
            j += 1
            if balance <= 0:
                break
        while j < len(lines):
            if clean(lines[j]).strip() and indent(lines[j]) <= depth:
                break
            j += 1
        while j > i + 1 and not lines[j - 1].strip():
            j -= 1
        yield match[2], i, j


def bounded(payload, budget):
    # Bound serialized bytes, including JSON escapes, not estimated tokens.
    return len(json.dumps(payload, ensure_ascii=True).encode("ascii")) <= budget


def retrieve(root, catalog, symbol, path=None, max_lines=60, budget=8000, callers=8):
    if not re.fullmatch(r"[A-Za-z_]\w*", symbol):
        raise ValueError("Use an exact function identifier")
    result = {"revision": catalog["revision"], "dirty": catalog["dirty"],
              "symbol": symbol, "definitions": [], "lexical_calls": [],
              "truncated": False}
    if path and path not in catalog["files"]:
        folder, _, name = path.rpartition("/")
        if folder == "godot-cove" and name in GAME_ROUTES["aliases"]:
            path = f"{folder}/{GAME_ROUTES['aliases'][name]}"
    regex = re.compile(r"\b" + re.escape(symbol) + r"\s*\(")
    for name in catalog["files"]:
        if not name.endswith(".gd"):
            continue
        source = root / name
        if source.is_symlink() or not source.resolve().is_relative_to(root):
            continue
        lines = source.read_text(encoding="utf-8-sig").splitlines()
        spans = list(functions(lines))
        for fn, start, end in spans:
            if fn != symbol or (path and path != name):
                continue
            stop = min(end, start + max_lines)
            entry = {"path": name, "start": start + 1, "end": stop,
                     "function_end": end, "partial": stop < end,
                     "source": "\n".join(lines[start:stop])}
            result["definitions"].append(entry)
            if not bounded(result, budget):
                result["definitions"].pop()
                result["truncated"] = True
        for i, line in enumerate(lines):
            if not regex.search(clean(line)) or FUNC.match(line):
                continue
            if len(result["lexical_calls"]) >= callers:
                result["truncated"] = True
                break
            owner = next((fn for fn, a, z in reversed(spans) if a <= i < z), None)
            result["lexical_calls"].append({"path": name, "line": i + 1,
                                            "function": owner, "text": line.strip()[:240]})
            if not bounded(result, budget):
                result["lexical_calls"].pop()
                result["truncated"] = True
                break
    # Definitions take priority over caller hints when the budget is tight.
    while not bounded(result, budget) and result["lexical_calls"]:
        result["lexical_calls"].pop()
        result["truncated"] = True
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("symbol")
    p.add_argument("--path", help="Exact repository-relative .gd path for definition")
    p.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument("--lines", type=int, choices=range(1, 121), default=60)
    p.add_argument("--budget", type=int, choices=range(1024, 24001), default=8000)
    p.add_argument("--callers", type=int, choices=range(0, 21), default=8)
    a = p.parse_args()
    root = a.root.resolve()
    result = retrieve(root, build(root), a.symbol, a.path, a.lines, a.budget, a.callers)
    print(json.dumps(result, ensure_ascii=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
