# Helicopter Flying Simulator

A browser-based helicopter flying simulator built with three.js. Learn what every switch, lever and gauge does, start the helicopter from cold yourself, then hover and fly.

**▶ Play in the browser:** https://yaroshitel.github.io/Helicopter-simulator-for-public-use/

**🖥 Desktop app (Windows / macOS / Linux, no browser needed, updates itself):** download once from the [latest release](https://github.com/Yaroshitel/Helicopter-simulator-for-public-use/releases/latest), see [DESKTOP.md](DESKTOP.md).

## Helicopters

| | Robinson R44 | Mil Mi-8MTV |
|---|---|---|
| Weight | ~1 t | ~10.5 t |
| Engine | 1 × Lycoming O-540 piston | 2 × TV3-117 turboshaft + AI-9V APU |
| Main rotor | 2 blades, teetering, 10 m, turns counter-clockwise | 5 blades, articulated, 21 m, turns clockwise |
| Start | key, magnetos, belt clutch, governor | APU → air starter → ignition, condition levers, correction grip |
| Landing gear | skids | wheels with parking brake |
| Instruments | knots, feet, ft/min | km/h, metres, m/s (Soviet style) |

## Features

- Cold-start and shutdown lessons for each aircraft that tick off automatically and highlight the next control
- Hover over (or aim at, with Alt) any switch or gauge to learn what it does
- Built-in pilot's manual (press **M**) with pictures, diagrams and a guide to reading every round instrument
- Flight model with rotor RPM, governors, ground effect, translational lift, torque, vortex ring state, turbine lag and autorotation
- Rotor-driven handling: damping comes from the rotor disk itself (no artificial damping), gyroscopic pitch↔roll cross-coupling, flap-back that grows with collective, dynamic inflow and realistic inertias. Optional limited-authority SAS / attitude hold (HeliSAS-style on the R44, AP-34 with heading hold on the Mi-8) that works through the controls, off by default
- A river-valley world: a town of Soviet-era panel blocks and private houses with tin roofs, a ferro-alloy plant with smoking chimneys, a railway with a freight train, a bridge, moving traffic, forests, vineyards, a hilltop church and a high-voltage line; windows and street lights come on at night
- Day/night cycle with a moving sun, golden-hour sunsets, stars, moon, sun glare and lens flare, and airfield lights at night (time of day and cycle speed in the side panel, **N** = +1 hour)
- Glossy clear-coated paint and polished metal with live sky reflections, a reflective lake
- HD procedural textures and normal maps (rivets, panel seams, camouflage, concrete, asphalt, brushed metal)
- Procedural engine, turbine, rotor and tail-rotor sound

## Controls

| Input | Action |
|---|---|
| Mouse | Cyclic (roll / pitch) |
| W / S | Collective up / down |
| A / D | Yaw pedals left / right |
| T / G | Throttle (R44) / correction grip (Mi-8) |
| Hold Alt | Free look — aim the dot at a switch and click (right-click = back) |
| V / C | 1st ⇄ 3rd person / cycle cameras |
| M | Pilot's manual |
| Space / X | Centre cyclic / pedals |
| N | Advance the time of day by one hour |
| Esc | Release the mouse |

Runs in Chrome or Edge on a desktop. Needs an internet connection to load three.js from a CDN.

*For learning and entertainment only — not an approved training device and not a substitute for any aircraft's flight manual.*
