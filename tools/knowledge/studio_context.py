"""Select worker context from a saved catalog and compact GitHub task metadata."""
import json
import sys

from github_context import summarize
from index import query
from start_task import guides, keywords


def select(catalog, note, tasks):
    terms = keywords(note)
    phrase = " ".join(terms)
    by_number = {item["number"]: item for item in tasks}
    related = summarize(tasks, phrase, 3)["matches"] if terms else []
    return {"matches": query(catalog, phrase, 10), "guides": guides(terms),
            "tasks": [by_number[item["number"]] for item in related]}


if __name__ == "__main__":
    args = json.load(sys.stdin)
    print(json.dumps(select(**args), ensure_ascii=True))
