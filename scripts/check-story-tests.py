#!/usr/bin/env python3
"""Traceability check between docs/user-stories.md and e2e/epics/*.spec.ts.

Verifies:
  1. Stories marked '✅ tested' have a matching 'US-0xx' test reference in a spec file.
  2. Stories marked '🚧 built' / '📋 planned' are NOT expected to have tests (warning only
     if they do, since a test implies it should be ✅).

Usage:
  python3 scripts/check-story-tests.py [--strict]

Exit codes: 0 = ok, 1 = mismatch found (with --strict), 2 = files missing.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORIES = os.path.join(ROOT, "docs", "user-stories.md")
SPEC_DIR = os.path.join(ROOT, "e2e", "epics")

ID_RE = re.compile(r"US-(\d{3})")
STATUS_RE = re.compile(r"\*\*Status:.*?([✅🚧📋])\s*(?:tested|built|planned)")
# All US-0xx ids inside a test( ... ) title — supports multi-id titles like US-013 US-021 US-097.
TEST_LINE_RE = re.compile(r"\btest\(")
ID_IN_LINE_RE = re.compile(r"US-(\d{3})")


def load_spec_ids():
    ids = set()
    for name in sorted(os.listdir(SPEC_DIR)):
        if not name.endswith(".spec.ts"):
            continue
        with open(os.path.join(SPEC_DIR, name), encoding="utf-8") as fh:
            for line in fh:
                if TEST_LINE_RE.search(line):
                    ids.update(ID_IN_LINE_RE.findall(line))
    return ids


def parse_stories():
    stories = {}
    current = None
    with open(STORIES, encoding="utf-8") as fh:
        for line in fh:
            m = ID_RE.search(line)
            if m and line.lstrip().startswith("###"):
                current = m.group(1)
                stories[current] = {"status": None}
            elif current and stories[current]["status"] is None:
                sm = STATUS_RE.search(line)
                if sm:
                    stories[current]["status"] = sm.group(1)
    return stories


def main():
    strict = "--strict" in sys.argv
    if not os.path.exists(STORIES):
        print(f"FATAL: {STORIES} not found"); return 2
    if not os.path.isdir(SPEC_DIR):
        print(f"FATAL: {SPEC_DIR} not found"); return 2

    spec_ids = load_spec_ids()
    stories = parse_stories()

    problems = []
    # Every tested story must have a test.
    for sid, info in sorted(stories.items(), key=lambda kv: int(kv[0])):
        tested = info["status"] == "✅"
        has_test = sid in spec_ids
        status_label = info["status"] if info["status"] else "UNKNOWN"
        if tested and not has_test:
            problems.append(f"US-{sid} marked ✅ tested but has NO test reference in e2e/epics/")
        elif not tested and has_test:
            problems.append(f"US-{sid} ({status_label}) has a test but is not marked ✅ tested — update docs/user-stories.md")

    # Tests that reference unknown stories.
    known = set(stories)
    for sid in sorted(spec_ids):
        if sid not in known:
            problems.append(f"US-{sid} referenced in specs but missing from docs/user-stories.md")

    if problems:
        print(f"{len(problems)} traceability issue(s):")
        for p in problems:
            print(f"  - {p}")
        if strict:
            return 1
        print("(non-strict: run with --strict to fail)")
        return 1
    print(f"OK: {len(stories)} stories, {len(spec_ids)} test refs, all consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
