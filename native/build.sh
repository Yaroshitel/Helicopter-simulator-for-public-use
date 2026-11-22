#!/usr/bin/env bash
# Builds everything a GitHub Release needs into ../build/release/:
#   HelicopterSim-Windows.zip, HelicopterSim-macOS.zip, HelicopterSim-Linux.zip  - the full app (download once)
#   game.pck   - mechanics update pack (flight model, cockpits, UI, sound)
#   world.pck  - world update pack (terrain data + world builder); only downloaded when it changed
#   manifest.json - build number, world id, engine version, file sizes and SHA-256, notes
# Usage: ./build.sh [build-number] [notes]      Needs Godot 4.4.1 on PATH as "godot" plus its export templates.
set -euo pipefail
cd "$(dirname "$0")"
BUILD="${1:-0}"; NOTES="${2:-}"
ENGINE="$(godot --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')"
[[ "$ENGINE" =~ ^[0-9]+\.[0-9]+$ ]] && ENGINE="$ENGINE.0"
# the world id changes only when the world's own files change
WORLD="$(cat baked/*.bin scripts/world_builder.gd shaders/world/*.gdshader | sha256sum | cut -c1-12)"
cp version.json /tmp/version.json.bak.$$; trap 'cp /tmp/version.json.bak.$$ version.json; rm -f /tmp/version.json.bak.$$' EXIT
printf '{"build": %d, "world": "%s", "engine": "%s"}\n' "$BUILD" "$WORLD" "$ENGINE" > version.json

godot --headless --import >/dev/null 2>&1 || true
godot --headless -s tools/dump_licenses.gd
OUT=../build/release
rm -rf ../build && mkdir -p ../build/windows ../build/macos ../build/linux ../build/packs $OUT
godot --headless --export-release "Windows" ../build/windows/HelicopterSim.exe
godot --headless --export-release "macOS" ../build/macos/HelicopterSim.zip
godot --headless --export-release "Linux" ../build/linux/HelicopterSim.x86_64
godot --headless --export-pack "GamePack" ../build/packs/game.pck
godot --headless --export-pack "WorldPack" ../build/packs/world.pck
for d in windows macos linux; do cp LICENSE.txt THIRD_PARTY_LICENSES.txt ../build/$d/; cp ../DESKTOP.md ../build/$d/README.md; done
(cd ../build/windows && zip -9 -q -r ../release/HelicopterSim-Windows.zip HelicopterSim.exe LICENSE.txt THIRD_PARTY_LICENSES.txt README.md)
(cd ../build/linux && zip -9 -q -r ../release/HelicopterSim-Linux.zip HelicopterSim.x86_64 LICENSE.txt THIRD_PARTY_LICENSES.txt README.md)
(cd ../build/macos && rm -rf app && mkdir app && cd app && unzip -q ../HelicopterSim.zip && cp ../LICENSE.txt ../THIRD_PARTY_LICENSES.txt ../README.md . \
  && zip -9 -q -r -y ../../release/HelicopterSim-macOS.zip .)
cp ../build/packs/game.pck ../build/packs/world.pck $OUT/
python3 - "$OUT" "$BUILD" "$WORLD" "$ENGINE" "$NOTES" <<'EOF'
import hashlib, json, os, sys
out, build, world, engine, notes = sys.argv[1:]
files = {f: {"size": os.path.getsize(os.path.join(out, f)), "sha256": hashlib.sha256(open(os.path.join(out, f), "rb").read()).hexdigest()}
         for f in ("game.pck", "world.pck")}
json.dump({"build": int(build), "world": world, "engine": engine, "notes": notes, "files": files}, open(os.path.join(out, "manifest.json"), "w"), indent=2)
EOF
cat $OUT/manifest.json; echo; ls -la $OUT
