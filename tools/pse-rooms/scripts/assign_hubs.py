#!/usr/bin/env python3
import json, subprocess, time, re

BASE = "https://hubs.chemie-lernen.org"
TOKEN = open("/tmp/owner_token.txt").read().strip()
LIVE = json.load(open("/tmp/live_hubs.json"))
SYM_ARCH = json.load(open("/tmp/symbol_to_archetype.json"))
sids = json.load(open("/tmp/scene_sids.json"))


def patch(hub_sid, body, attempt=0):
    cmd = ["curl", "-sk", "-X", "PATCH", f"{BASE}/api/v1/hubs/{hub_sid}",
           "-H", "content-type: application/json",
           "-H", f"Authorization: Bearer {TOKEN}", "-w", "\n__S__%{http_code}",
           "-d", json.dumps(body)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    out = r.stdout
    status = None
    if "__S__" in out:
        out, _, s = out.rpartition("__S__")
        status = int(s.strip())
    return status


ok = fail = 0
for h in LIVE:
    m = re.search(r"\(([^)]+)\)", h["name"])
    sym = m.group(1) if m else None
    arch = SYM_ARCH.get(sym, "ElementRoom") if sym else "ElementRoom"
    sid = sids[arch]
    body = {"hub": {"scene_id": sid}}
    status = patch(h["sid"], body)
    attempts = 1
    while status == 403 and attempts < 4:
        time.sleep(2.5 * attempts)
        status = patch(h["sid"], body)
        attempts += 1
    if status in (200, 204):
        ok += 1
    else:
        fail += 1
        if fail <= 10:
            print(f"  ! {h['sid']} ({sym}/{arch}): http={status}")
    time.sleep(0.5)

print(f"=== DONE ok={ok} fail={fail} ===")
