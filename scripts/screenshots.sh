#!/usr/bin/env bash
# Capture App Store screenshots on a 13-inch iPad simulator (2064x2752, portrait).
# Uses the debug-only screenshot mode: -ui-testing -screenshot <scene>.
# Usage: scripts/screenshots.sh   (writes to screenshots/)
set -euo pipefail

bundle=org.polyglotlearn.shellycodes
out=screenshots
scenes=(home level success error freedraw gallery shells)

device=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
for runtime in sorted(runtimes, key=lambda r: [int(x) for x in r.split("iOS-")[-1].split("-") if x.isdigit()], reverse=True):
    for d in runtimes[runtime] if "iOS" in runtime else []:
        if d["name"].startswith("iPad Pro 13-inch"):
            print(d["udid"]); sys.exit()
sys.exit("no iPad Pro 13-inch simulator; install one in Xcode > Settings > Components")
')

xcodebuild build -project ShellyCodes.xcodeproj -scheme ShellyCodes -configuration Debug \
  -destination "id=$device" -derivedDataPath build/screenshots -quiet

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl status_bar "$device" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --dataNetwork wifi
xcrun simctl install "$device" build/screenshots/Build/Products/Debug-iphonesimulator/ShellyCodes.app

mkdir -p "$out"
for i in "${!scenes[@]}"; do
  scene=${scenes[$i]}
  xcrun simctl terminate "$device" "$bundle" >/dev/null 2>&1 || true
  xcrun simctl launch "$device" "$bundle" -ui-testing -screenshot "$scene" >/dev/null
  sleep 4
  file="$out/$((i + 1))-$scene.png"
  xcrun simctl io "$device" screenshot "$file" >/dev/null 2>&1
  echo "$file"
done
xcrun simctl status_bar "$device" clear
