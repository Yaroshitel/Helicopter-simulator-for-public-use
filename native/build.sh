#!/usr/bin/env bash
# Builds the Windows .exe and the macOS .app (universal) and packages them into ../releases/.
# Needs Godot 4.4.1 on PATH as "godot" and the 4.4.1 export templates installed.
set -euo pipefail
cd "$(dirname "$0")"
godot --headless --import >/dev/null 2>&1 || true
godot --headless -s tools/dump_licenses.gd
rm -rf ../build && mkdir -p ../build/windows ../build/macos ../releases
godot --headless --export-release "Windows" ../build/windows/HelicopterSim.exe
godot --headless --export-release "macOS" ../build/macos/HelicopterSim.zip
for d in windows macos; do cp LICENSE.txt THIRD_PARTY_LICENSES.txt ../build/$d/; cp ../DESKTOP.md ../build/$d/README.md; done
(cd ../build/windows && rm -f ../../releases/HelicopterSim-Windows.zip && zip -9 -q -r ../../releases/HelicopterSim-Windows.zip HelicopterSim.exe LICENSE.txt THIRD_PARTY_LICENSES.txt README.md)
(cd ../build/macos && rm -rf app && mkdir app && cd app && unzip -q ../HelicopterSim.zip && cp ../LICENSE.txt ../THIRD_PARTY_LICENSES.txt ../README.md . \
  && rm -f ../../../releases/HelicopterSim-macOS.zip && zip -9 -q -r -y ../../../releases/HelicopterSim-macOS.zip .)
ls -la ../releases
