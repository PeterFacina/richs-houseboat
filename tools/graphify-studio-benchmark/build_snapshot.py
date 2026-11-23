"""Build an isolated offline Graphify snapshot of a Godot project."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import time

import networkx as nx
from graphify.cluster import cluster
from graphify.export import to_json
from graphify.extract import extract
from tree_sitter_language_pack import get_parser

def build(project, output):
    started = time.perf_counter()
    output.mkdir(parents=True, exist_ok=False)
    files = []
    for folder, directories, names in os.walk(project):
        directories[:] = sorted(
            name for name in directories if not name.startswith(".")
            and not (Path(folder) / name).is_symlink()
            and not (Path(folder) / name).is_junction()
        )
        files.extend(Path(folder) / name for name in sorted(names)
                     if not (Path(folder) / name).is_symlink())
    inputs = sorted(path for path in files if path.suffix.lower() in {".gd", ".tscn", ".tres", ".cs"})
    relative = lambda path: path.relative_to(project).as_posix()
    hashes = {relative(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    raw = extract(inputs, cache_root=output)
    for entry in raw["nodes"] + raw["edges"]:
        path = Path(entry.get("source_file") or ".")
        if path.is_absolute() and path.is_relative_to(project):
            entry["source_file"] = relative(path)
    graph = nx.MultiGraph()
    for node in raw["nodes"]:
        graph.add_node(node["id"], **{key: value for key, value in node.items() if key != "id"})
    unresolved = []
    for edge in raw["edges"]:
        source, target = edge["source"], edge["target"]
        if source in graph and target in graph:
            graph.add_edge(source, target, key=(edge["relation"] + ":" + edge.get("confidence", "")),
                           _src=source, _tgt=target, **{k: v for k, v in edge.items()
                                                       if k not in {"source", "target"}})
        else:
            unresolved.append(edge)

    by_file = {data["source_file"]: node for node, data in graph.nodes(data=True)
               if data.get("source_file") and
               data["label"] == Path(data["source_file"]).name}
    functions = {(data.get("source_file"), data["label"]): node
                 for node, data in graph.nodes(data=True)}
    parser = get_parser("gdscript")
    parser_errors, unmatched_rpc = {}, []
    for path in inputs:
        source = relative(path)
        if path.suffix == ".gd":
            root = parser.parse(path.read_bytes()).root_node
            if root.has_error:
                pending, errors = [root], []
                while pending:
                    node = pending.pop()
                    if node.is_error or node.is_missing:
                        errors.append(node.start_point.row + 1)
                    pending.extend(child for child in node.children if child.has_error)
                parser_errors[source] = sorted(set(errors))
            content = path.read_text(encoding="utf-8-sig")
            for match in re.finditer(r"(?m)^\s*(@rpc\([^\n]*\))[ \t]*\n[ \t]*func (\w+)\(", content):
                method = functions.get((source, match[2] + "()"))
                line = content.count("\n", 0, match.start(1)) + 1
                if method is None:
                    unmatched_rpc.append(f"{source}:{line}")
                    continue
                rpc = f"rpc:{source}:{line}"
                graph.add_node(rpc, label=f"{match[1]} {match[2]}", source_file=source,
                               source_location=f"L{line}", file_type="code")
                graph.add_edge(rpc, method, relation="annotates_rpc", confidence="EXTRACTED",
                               _src=rpc, _tgt=method)
        elif path.suffix == ".tscn" and source in by_file:
            resources, scene_nodes = {}, {}
            current = None
            for line, value in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
                attrs = dict(re.findall(r'(\w+)="([^"]*)"', value))
                if value.startswith("[ext_resource ") and {"id", "path"} <= attrs.keys():
                    resources[attrs["id"]] = attrs["path"].removeprefix("res://")
                if value.startswith("["):
                    current = None
                if value.startswith("[node ") and "name" in attrs:
                    parent = attrs.get("parent")
                    node_path = "." if parent is None else attrs["name"] if parent == "." else f"{parent}/{attrs['name']}"
                    current = f"scene:{source}:{node_path}"
                    scene_nodes[node_path] = current
                    graph.add_node(current, label=attrs["name"], source_file=source,
                                   source_location=f"L{line}", file_type="code")
                    container = by_file[source] if parent is None else scene_nodes.get(parent)
                    if container:
                        graph.add_edge(container, current, relation="contains_scene_node",
                                       confidence="EXTRACTED", _src=container, _tgt=current)
                script = re.fullmatch(r'\s*script\s*=\s*ExtResource\("([^"]+)"\)\s*', value)
                if current and script:
                    target = by_file.get(resources.get(script[1]))
                    if target:
                        graph.add_edge(current, target, relation="attaches_script",
                                       confidence="EXTRACTED", _src=current, _tgt=target)

    config = project / "project.godot"
    for line, value in enumerate(config.read_text(encoding="utf-8-sig").splitlines(), 1):
        main = re.fullmatch(r'run/main_scene="res://([^"]+)"', value)
        if main and main[1] in by_file:
            graph.add_node("project", label="project.godot", source_file="project.godot",
                           source_location=f"L{line}", file_type="code")
            target = by_file[main[1]]
            graph.add_edge("project", target, relation="runs_main_scene",
                           confidence="EXTRACTED", _src="project", _tgt=target)

    missing = [relative(path) for path in inputs if relative(path) not in by_file]
    if missing:
        raise RuntimeError(f"Missing indexed files: {missing}")
    assert hashes == {relative(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
    communities = cluster(nx.Graph(graph))
    to_json(graph, communities, str(output / "graph.json"))
    report = {
        "project": str(project), "indexed": sorted(by_file),
        "skipped": [relative(path) for path in files if path not in inputs],
        "excluded_directories": "hidden directories, symlinks and junctions",
        "parser_error_lines": parser_errors, "unmatched_rpc": unmatched_rpc,
        "unresolved_edges": unresolved, "nodes": graph.number_of_nodes(),
        "edges": graph.number_of_edges(),
        "relations": dict(Counter((d["relation"] + "/" + d["confidence"])
                                  for _, _, d in graph.edges(data=True))),
        "sha256_before_and_after": hashes,
        "seconds": round(time.perf_counter() - started, 3),
    }
    (output / "coverage.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print({k: report[k] for k in ("nodes", "edges", "relations", "parser_error_lines", "seconds")})


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("project", type=Path)
    cli.add_argument("output", type=Path)
    args = cli.parse_args()
    project, output = args.project.resolve(), args.output.resolve()
    if not (project / "project.godot").is_file() or output.is_relative_to(project):
        cli.error("Choose a Godot root and a fresh output directory outside it.")
    build(project, output)
