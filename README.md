# Helicopter Training Simulator

A browser-based helicopter training simulator built with three.js. Learn what every switch, lever and gauge does, start the helicopter from cold yourself, then hover and fly.

**▶ Play:** https://yaroshitel.github.io/r44-trainer/

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
| Esc | Release the mouse |

Runs in Chrome or Edge on a desktop. Needs an internet connection to load three.js from a CDN.

*For learning and entertainment only — not an approved training device and not a substitute for any aircraft's flight manual.*
