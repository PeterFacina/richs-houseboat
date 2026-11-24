"""Compact read-only GitHub issue/PR metadata and selected file patches."""
import argparse
import json
import os
import re
from urllib.request import Request, urlopen

REPO = "PeterFacina/richs-houseboat"
BASE = "https://api.github.com/repos/" + REPO


def get(route):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "houseboat-knowledge"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    with urlopen(Request(BASE + route, headers=headers), timeout=15) as response:
        return json.load(response)


def pages(route, fetch=get, cap=10):
    for page in range(1, cap + 1):
        batch = fetch(route + ("&" if "?" in route else "?") + "per_page=100&page=" + str(page))
        yield from batch
        if len(batch) < 100:
            return
    raise RuntimeError("Pagination cap reached; results incomplete, use targeted GitHub search")


def summarize(items, phrase, limit):
    words = set(re.findall(r"\w+", phrase.lower())) - {"the", "and", "for", "with"}
    ranked = []
    for item in items:
        title = item.get("title") or ""
        body = item.get("body") or ""
        labels = [x["name"] for x in item.get("labels", [])]
        hay = (title + " " + body + " " + " ".join(labels)).lower()
        score = sum(3 if w in title.lower() else 1 for w in words if w in hay)
        if score or not words:
            ranked.append((score, item["number"], {
                "number": item["number"], "title": title[:220],
                "url": item.get("html_url"), "draft": item.get("draft"),
                "assignees": [x["login"] for x in item.get("assignees", [])],
                "labels": labels}))
    ranked.sort(key=lambda x: (-x[0], x[1]))
    return {"matches": [x[2] for x in ranked[:limit]], "total_matches": len(ranked),
            "truncated": len(ranked) > limit}


def select_patches(items, paths, budget):
    result = {"files": [], "truncated": False}
    for item in items:
        name = item["filename"]
        if paths and name not in paths and item.get("previous_filename") not in paths:
            continue
        entry = {"path": name, "status": item.get("status"),
                 "additions": item.get("additions"), "deletions": item.get("deletions")}
        if paths:
            entry["patch"] = item.get("patch")
            entry["patch_may_be_incomplete"] = True
        result["files"].append(entry)
        if len(json.dumps(result, ensure_ascii=True)) > budget:
            result["files"].pop()
            result["truncated"] = True
            break
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--query", default="")
    p.add_argument("--limit", type=int, choices=range(1, 21), default=8)
    p.add_argument("--pr", type=int)
    p.add_argument("--path", action="append", default=[])
    p.add_argument("--budget", type=int, choices=range(1024, 24001), default=8000)
    a = p.parse_args()
    if a.pr:
        output = select_patches(pages("/pulls/" + str(a.pr) + "/files"), a.path, a.budget)
    else:
        issues = (i for i in pages("/issues?state=open") if "pull_request" not in i)
        output = {"issues": summarize(issues, a.query, a.limit),
                  "pulls": summarize(pages("/pulls?state=open"), a.query, a.limit),
                  "warning": "Keyword shortlist only; inspect relevant diffs and broaden if necessary."}
    print(json.dumps(output, ensure_ascii=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
