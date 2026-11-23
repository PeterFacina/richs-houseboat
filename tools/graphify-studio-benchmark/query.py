"""Return a small file shortlist and its directly observed graph relationships."""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import re


def retrieve(graph, keywords, budget, limit):
    terms = set(re.findall(r"[a-z0-9]+", keywords.lower()))
    nodes = {node["id"]: node for node in graph["nodes"] if node.get("source_file")}
    scores = defaultdict(dict)
    for node in nodes.values():
        path = node["source_file"]
        name = re.sub(r"([a-z])([A-Z])", r"\1 \2", node["label"]).lower()
        words = set(re.findall(r"[a-z0-9]+", name))
        for term in terms:
            if term in words:
                weight = 4 if node["label"] == Path(path).name else 2
            elif any(word.startswith(term) for word in words):
                weight = 1
            else:
                continue
            scores[path][term] = max(weight, scores[path].get(term, 0))
    ranked = sorted(scores, key=lambda path: (-sum(scores[path].values()), path))[:limit]
    lines, selected = [], []
    remaining = budget * 3

    def add(line):
        nonlocal remaining
        size = len(line.encode("utf-8")) + 1
        if size > remaining:
            return False
        lines.append(line)
        remaining -= size
        return True

    for path in ranked:
        if add(f"FILE {path} ({', '.join(sorted(scores[path]))})"):
            selected.append(path)
    relations = {"imports_from", "attaches_script", "instances", "runs_main_scene"}
    edges = []
    for edge in graph["links"]:
        source, target = edge["_src"], edge["_tgt"]
        if (edge["relation"] not in relations or edge["confidence"] != "EXTRACTED"
                or source not in nodes or target not in nodes):
            continue
        left, right = nodes[source]["source_file"], nodes[target]["source_file"]
        if left in selected and right in selected and left != right:
            edges.append((left, right, edge))
    retained = []
    for left, right, edge in sorted(edges, key=lambda row: (row[0], row[1], row[2]["relation"])):
        if add(f"{left} --{edge['relation']}--> {right}"):
            retained.append((edge["_src"], edge["_tgt"], edge["relation"]))
    return "\n".join(lines), selected, retained


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("keywords", help="Use discriminating terms from the task.")
    cli.add_argument("--snapshot", type=Path, default=Path(__file__).resolve().parent / "richs-houseboat")
    cli.add_argument("--budget", type=int, default=240, help="Output cap at three UTF-8 bytes per estimated token.")
    cli.add_argument("--limit", type=int, default=6)
    args = cli.parse_args()
    if args.budget < 40 or args.limit < 1:
        cli.error("Use a budget of at least 40 and a positive file limit.")
    graph = json.loads((args.snapshot / "graph.json").read_text(encoding="utf-8"))
    result, _, _ = retrieve(graph, args.keywords, args.budget, args.limit)
    print(result or "No graph matches. Search project source with rg.")
