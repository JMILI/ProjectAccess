#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:18200}"
API_URL="${BASE_URL%/}/api/projects"
export API_URL

python3 - <<'PY'
import json
import os
import sys
import time
import urllib.request
import urllib.error

api_url = os.environ.get("API_URL")
timeout = 20
retries = 3
retry_delay = 2
default_headers = {
    "User-Agent": "ProjectAccessLinkChecker/1.0",
    "Accept": "*/*",
}

def fetch_json(url):
    req = urllib.request.Request(url, headers=default_headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", "ignore"))

def check_url_once(url):
    req = urllib.request.Request(url, headers=default_headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return True, resp.status, ""

def check_url(url):
    last_err = ""
    last_status = None
    for attempt in range(1, retries + 1):
        try:
            ok, status, msg = check_url_once(url)
            return ok, status, msg
        except urllib.error.HTTPError as e:
            last_status = e.code
            last_err = f"HTTPError {e.code}"
            if e.code in (404, 502, 503, 504) and attempt < retries:
                time.sleep(retry_delay)
                continue
            return False, e.code, last_err
        except Exception as e:
            last_err = f"{type(e).__name__}: {e}"
            if attempt < retries:
                time.sleep(retry_delay)
                continue
            return False, last_status, last_err
    return False, last_status, last_err

try:
    projects = fetch_json(api_url)
except Exception as e:
    print(f"[FAIL] load {api_url}: {e}")
    sys.exit(2)

if not isinstance(projects, list):
    print(f"[FAIL] unexpected /api/projects response type: {type(projects).__name__}")
    sys.exit(2)

ok = 0
fail = 0

print(f"API: {api_url}")
print(f"Projects: {len(projects)}")
print("-" * 72)

for p in projects:
    pid = p.get("id", "<unknown>")
    print(f"[{pid}]")
    for label, key in [("GitHub", "github_url"), ("Tunnel", "tunnel_url")]:
        url = p.get(key)
        if not url:
            fail += 1
            print(f"  - {label:<6} MISSING")
            continue
        is_ok, status, msg = check_url(url)
        if is_ok:
            ok += 1
            print(f"  - {label:<6} OK      {status}  {url}")
        else:
            fail += 1
            detail = f"{status}" if status is not None else "NO_STATUS"
            print(f"  - {label:<6} FAILED  {detail}  {url}  ({msg})")
    print()

print("-" * 72)
print(f"Result: OK={ok}, FAIL={fail}")
sys.exit(1 if fail else 0)
PY
