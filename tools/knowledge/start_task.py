"""Read-only task bootstrap: local revision, guide hints, source symbols and live overlap."""
import argparse
import json
import re
import subprocess
from pathlib import Path
from urllib.error import URLError
from index import build, git, query
from github_context import pages, summarize

ROUTES = (
    ("world map terrain town roads municipal traffic identity architecture", "docs/ARCHITECTURE.md"),
    ("rich shannon quest questline npc restoration", "docs/systems/QUESTS.md"),
    ("boat helm water drift wave thrust wind river dock moor ignition", "docs/systems/BOAT-WATER.md"),
    ("multiplayer host guest peer replication sync network", "docs/systems/MULTIPLAYER.md"),
    ("fishing fish player input tool inventory", "docs/systems/FISHING-PLAYER.md"),
    ("xp skill job economy save progression research mowing", "docs/systems/PROGRESSION-ECONOMY.md"),
    ("ai discord worker prompt retrieval agent", "docs/AI-WORKFLOW.md"),
    ("test ci build verification", "docs/BUILD-CHECKS.md"),
)
STOP = set("a an the how what when where why is are does do of to in on with and or for it its my our this that please investigate explain fix make nobody someone controlling controls".split())


def keywords(task):
    return list(dict.fromkeys(w for w in re.findall(r"\w+", task.lower())
                              if len(w) > 1 and w not in STOP))[:12]


def guides(terms):
    ranked = []
    for words, path in ROUTES:
        score = sum(1 for t in terms if any(t == w or (len(t) >= 4 and t.startswith(w)) for w in words.split()))
        if score:
            ranked.append((-score, path))
    return [path for _, path in sorted(ranked)[:3]]


def live(phrase, fetch_pages=pages):
    try:
        issues = (i for i in fetch_pages("/issues?state=open") if "pull_request" not in i)
        return {"status": "queried",
                "issues": summarize(issues, phrase, 5),
                "pulls": summarize(fetch_pages("/pulls?state=open"), phrase, 5),
                "warning": "Shortlist only; verify issue ownership, broaden search and inspect relevant PR patches."}
    except (OSError, URLError, ValueError, RuntimeError, KeyError, TypeError) as exc:
        return {"status": "failed", "error_type": type(exc).__name__,
                "warning": "Live overlap unknown; retry with another GitHub tool. Do not infer no overlap."}


def bootstrap(root, task, fetch_pages=pages, offline=False):
    terms = keywords(task)
    if not terms:
        raise ValueError("Supply meaningful task keywords")
    catalog = build(root)
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip()
    dirty = bool(git(root, "status", "--porcelain", "--untracked-files=all").strip())
    try:
        cached_main = git(root, "rev-parse", "--verify", "refs/remotes/origin/main").decode().strip()
    except subprocess.CalledProcessError:
        cached_main = None
    matches = query(catalog, task, 4)
    for match in matches:
        match["symbols"] = match["symbols"][:4]
        match["references"] = match["references"][:3]
    return {"revision": catalog["revision"], "branch": branch, "worktree_dirty": dirty,
            "cached_origin_main": cached_main, "remote_main_freshness": "not checked; fetch separately when required",
            "keywords": terms, "read_first": ["AGENTS.md", "docs/ARCHITECTURE.md"],
            "identity": "docs/GAME-IDENTITY.md",
            "suggested_guides": guides(terms), "source_matches": matches,
            "github": {"status": "skipped", "warning": "Offline; overlap unknown"} if offline else live(" ".join(terms), fetch_pages),
            "next": ["Read relevant guides and applicable nested instructions.",
                     "Use retrieve.py EXACT_FUNCTION --path REPO_RELATIVE_PATH; verify callers.",
                     "Use github_context.py --pr NUMBER then --pr NUMBER --path PATH for relevant patches.",
                     "Expand search only as needed; report bootstrap and any fallback or missing checks."]}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("task", help="Short task description or keywords")
    p.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument("--offline", action="store_true", help="Skip network explicitly; overlap remains unknown")
    a = p.parse_args()
    try:
        result = bootstrap(a.root.resolve(), a.task, offline=a.offline)
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        p.error("Local bootstrap failed: " + type(exc).__name__)
    print(json.dumps(result, ensure_ascii=True, separators=(",", ":")))
    if result["github"]["status"] == "failed":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
