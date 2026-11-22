# Helicopter Flying Simulator — desktop edition (Windows & macOS)

A native desktop version of the simulator: its own game and its own app. It does **not** run in a browser and does not
use any web engine (no Chrome, no Edge/WebView2, no Safari/WebKit, no Electron). It is built with the
[Godot Engine](https://godotengine.org) (MIT licence) and renders directly through the graphics card
(Vulkan / Direct3D 12 on Windows, Metal on macOS, with an OpenGL fallback for older machines).

Typical memory use is a few hundred MB, much less than the browser version needs.

## Download & run

The ready-to-run apps are in [`releases/`](releases/):

| Platform | File | How to start |
|---|---|---|
| Windows 10/11 (64-bit) | `releases/HelicopterSim-Windows.zip` | Unzip, double-click `HelicopterSim.exe` |
| macOS 11+ (Apple Silicon and Intel, universal) | `releases/HelicopterSim-macOS.zip` | Unzip, drag `Helicopter Flying Simulator.app` to Applications, then open it (see below) |

No installation, no internet connection and no browser are needed.

**First start on Windows:** the app is not code-signed (signing needs a paid certificate), so SmartScreen may say
"Windows protected your PC". Click **More info → Run anyway**.

**First start on macOS:** the app is ad-hoc signed but not notarised by Apple (notarisation needs a paid Apple Developer
account), so Gatekeeper blocks the first launch. Either right-click the app → **Open** → **Open**, or go to
**System Settings → Privacy & Security** and click **Open Anyway**. If macOS says the app "is damaged", run once in Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/Helicopter Flying Simulator.app"
```

## What is in it

Everything from the web version, ported to native code:

- Robinson R44 and Mil Mi-8MTV with the same flight model (rotor RPM, governors, ground effect, translational lift,
  torque, vortex ring state, turbine lag, autorotation, dynamic inflow, optional SAS)
- Heavy, deliberate handling: small stick movements do little and the last part of the travel gives the real
  authority; a held stick settles at a held attitude; the airframe's inertia makes rates build and stop gradually.
  The tail rotor's sideways push is cancelled by the rotor rigging, and only changes in torque (a quick collective
  pull) swing the nose. Keyboard pedals spring back to centre, which holds the heading.
- Full cold-start and shutdown lessons that tick off automatically and highlight the next control
- Clickable cockpits: every switch, lever and gauge explains itself (hover, or hold **Alt** and aim)
- Live instrument panels, pilot's manual (**M**) with a live guide to every round instrument
- The river-valley world: airfield, lake, river, town, ferro-alloy plant with smoking chimneys, railway, bridge, traffic,
  forests, vineyards, hilltop church, high-voltage line
- Day/night cycle with sun, moon, stars, night lighting
- Procedural engine, turbine, rotor and tail-rotor sound
- Graphics quality setting (Low / Medium / High) on the start screen and in the side panel

## Controls

| Input | Action |
|---|---|
| Mouse | Cyclic (roll / pitch) — click the view to capture the mouse |
| W / S | Collective up / down |
| A / D | Yaw pedals left / right (spring back to centre on release) |
| T / G | Throttle (R44) / correction grip (Mi-8) |
| Hold Alt | Free look — aim the dot at a switch and click (right-click = back) |
| V / C | 1st ⇄ 3rd person / cycle cameras |
| M | Pilot's manual |
| Space / X | Centre cyclic / pedals |
| N | Advance the time of day by one hour |
| P / Backspace | Pause / reset |
| F11 | Full screen |
| Esc | Release the mouse |

Without capturing the mouse you can also point at switches and click them directly, and drag with the right mouse button to look around. Gamepads are supported.

## Building from source

The Godot project is in [`native/`](native/). You need Godot 4.4.1 and its export templates.

```bash
cd native
godot --headless --import
godot --headless --export-release "Windows" ../build/windows/HelicopterSim.exe
godot --headless --export-release "macOS" ../build/macos/HelicopterSim.zip
```

Both exports work from Windows, macOS or Linux. `native/build.sh` does the whole thing and packages the zips.
The terrain is pre-baked into `native/baked/`. If you change the valley layout in `scripts/util.gd`, re-bake it with
`godot --headless -s tools/bake_terrain.gd`.

## Licences

- The simulator's own code: MIT License, see [`native/LICENSE.txt`](native/LICENSE.txt).
- Godot Engine and the third-party libraries compiled into it: see
  [`native/THIRD_PARTY_LICENSES.txt`](native/THIRD_PARTY_LICENSES.txt). The same notices are shipped inside each
  download and shown in the game under **Licences & credits**.
- All 3D models, textures and sounds are generated procedurally by the program; no third-party art or audio is used.
- Robinson and R44 are trademarks of Robinson Helicopter Company; Mil and Mi-8 are trademarks of their respective
  owners. This is an independent educational project, not affiliated with or endorsed by them.

*For learning and entertainment only — not an approved training device and not a substitute for any aircraft's flight manual.*
