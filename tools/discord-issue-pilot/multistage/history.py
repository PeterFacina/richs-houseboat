"""Capture bounded completed task metadata for an offline retrieval experiment."""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "knowledge"))
from github_context import get  # noqa: E402


def title(text):
    text = re.sub(r"https?://\S+|\b(?:gh[pousr]_|github_pat_)\w+", "[redacted]", text)
    return " ".join(text.split())[:180]


def capture(before):
    records = []
    for item in get("/issues?state=closed&sort=created&direction=desc&per_page=100"):
        if (item.get("pull_request") or item.get("state_reason") != "completed"
                or not item.get("closed_at") or item["closed_at"] > before):
            continue
        records.append({"type": "issue", "number": item["number"], "title": title(item["title"]),
                        "completed": item["closed_at"]})
    for item in get("/pulls?state=closed&sort=created&direction=desc&per_page=100"):
        if item["base"]["ref"] != "main" or not item.get("merged_at") or item["merged_at"] > before:
            continue
        issues = sorted(set(int(number) for number in re.findall(
            r"\b(?:fix(?:es|ed)?|clos(?:e|es|ed)|resolv(?:e|es|ed))\s+#(\d+)\b", item.get("body") or "", re.I)))
        records.append({"type": "pull", "number": item["number"], "title": title(item["title"]),
                        "completed": item["merged_at"], "issues": issues})
    return {"through": before, "records": sorted(records, key=lambda item: (item["type"], item["number"]))}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--through", required=True, help="ISO UTC timestamp in YYYY-MM-DDTHH:MM:SSZ format")
    args = parser.parse_args()
    if not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", args.through):
        parser.error("Supply a UTC timestamp")
    print(json.dumps(capture(args.through), ensure_ascii=True, indent=2))
