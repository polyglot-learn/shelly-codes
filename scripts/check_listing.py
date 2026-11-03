#!/usr/bin/env python3
"""Check the App Store listing in APP_STORE.md against Apple's field limits."""
import re
import sys
from pathlib import Path

LIMITS = {
    "Name": 30, "Subtitle": 30, "Promotional text": 170, "Keywords": 100,
    "Description": 4000, "What's New": 4000,
}

text = Path(__file__).resolve().parent.parent.joinpath("APP_STORE.md").read_text()
failed = False
for field, limit in LIMITS.items():
    match = re.search(r"\*\*" + re.escape(field) + r"\*\*[^\n]*\n\n```\n(.*?)\n```", text, re.S)
    if not match:
        print(f"missing: {field}")
        failed = True
        continue
    value = match.group(1)
    ok = len(value) <= limit
    if field == "Keywords" and ", " in value:
        ok = False
        print("Keywords: remove spaces after commas")
    print(f"{'ok ' if ok else 'TOO LONG'} {field}: {len(value)}/{limit}")
    failed |= not ok
sys.exit(1 if failed else 0)
