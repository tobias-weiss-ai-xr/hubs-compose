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
SPEC_DIR = os.path.join(ROOT, "e2e", "epics")          # Playwright live tests
SERVICE_TEST_DIR = os.path.join(ROOT, "services", "reticulum", "test")  # Elixir mix tests

ID_RE = re.compile(r"US-(\d{3})")
STATUS_RE = re.compile(r"\*\*Status:.*?([✅🚧📋])\s*(?:tested|built|planned)")
# All US-0xx ids inside a test( ... ) title — supports multi-id titles like US-013 US-021 US-097.
TEST_LINE_RE = re.compile(r"\btest\(")
ID_IN_LINE_RE = re.compile(r"US-(\d{3})")

# In Elixir service tests, story ids appear in # US-0xx comment lines or test names.
ELIXIR_TEST_RE = re.compile(r"US-(\d{3})")


def load_spec_ids():
    ids = set()
    for name in sorted(os.listdir(SPEC_DIR)):
        if not name.endswith(".spec.ts"):
            continue
        with open(os.path.join(SPEC_DIR, name), encoding="utf-8") as fh:
            for line in fh:
                if TEST_LINE_RE.search(line):
                    ids.update(ID_IN_LINE_RE.findall(line))
    # Elixir service tests (mix test, run inside the reticulum container): any US-0xx in
    # the file (comments / test names) counts as coverage for that story.
    for dirpath, _dirs, files in os.walk(SERVICE_TEST_DIR):
        for name in sorted(files):
            if name.endswith(".exs"):
                with open(os.path.join(dirpath, name), encoding="utf-8") as fh:
                    ids.update(ELIXIR_TEST_RE.findall(fh.read()))
    return ids


def parse_stories():
    stories = {}
    current = None
    block = []
    with open(STORIES, encoding="utf-8") as fh:
        for line in fh:
            # Top-level sections (epic headers, summary tables) close any open story block.
            if line.startswith("## "):
                if current and block:
                    stories[current] = {"status": parse_status(block)}
                current = None
                block = []
                continue
            m = ID_RE.search(line)
            if m and line.lstrip().startswith("###"):
                if current and block:
                    stories[current] = {"status": parse_status(block)}
                current = m.group(1)
                block = [line]
            elif current:
                block.append(line)
    if current and block:
        stories[current] = {"status": parse_status(block)}
    return stories


def parse_status(block):
    joined = "".join(block)
    # 🧪 (service-tested marker) overrides the primary status marker.
    if "🧪" in joined:
        return "🧪"
    sm = STATUS_RE.search(joined)
    return sm.group(1) if sm else None


def main():
    strict = "--strict" in sys.argv
    if not os.path.exists(STORIES):
        print(f"FATAL: {STORIES} not found"); return 2
    if not os.path.isdir(SPEC_DIR):
        print(f"FATAL: {SPEC_DIR} not found"); return 2

    spec_ids = load_spec_ids()
    stories = parse_stories()

    problems = []
    # Every tested story (✅ live-tested or 🧪 service-tested) must have a test reference.
    for sid, info in sorted(stories.items(), key=lambda kv: int(kv[0])):
        tested = info["status"] in ("✅", "🧪")
        has_test = sid in spec_ids
        status_label = info["status"] if info["status"] else "UNKNOWN"
        if tested and not has_test:
            problems.append(f"US-{sid} marked {status_label} tested but has NO test reference (e2e/epics or services/reticulum/test)")
        elif not tested and has_test:
            problems.append(f"US-{sid} ({status_label}) has a test but is not marked ✅/🧪 tested — update docs/user-stories.md")

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
