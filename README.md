# Companion Chronicle

A private journal of the people you meet in World of Warcraft. Remember helpful
companions, record personal notes and recognize familiar faces next time.

- Record friendly or unfriendly encounters through the player context menu.
- Keep notes and mark trusted allies.
- Browse recent encounters and remembered players.
- Choose the illustrated Chronicle journal or a compact Modern layout.
- See personal reminders in groups, tooltips and supported friendly nameplates.

Your ratings and notes stay local. There are no shared scores or automatic
combat-based judgments.

## Development status

This addon is in development for **WoW Forever beta**, targeting Interface
**16001**. Compatibility with other clients is not claimed. Client testing is
partial; combat, taint and server-dependent behavior need further validation.
Development data is disposable, and migrations are not guaranteed.

**Known release blocker:** On tested Forever beta build **1.60.1.69913**, saved
players and notes disappear after `/reload`. Release publication is on hold
while persistence is investigated; journal data is not currently reliable.

## Installation

Download an addon ZIP from [Releases](https://github.com/Topping/Companion-Chronicle/releases)
when a release is available. Extract the `CompanionChronicle` folder into your
client's `Interface/AddOns` directory and enable **Companion Chronicle** in game.
GitHub's automatically generated source archives are not installable addon ZIPs.

## Usage

Open the journal with `/companionchronicle` or `/cchron`. Right-click a supported
player portrait or chat name to record an encounter or add a note. Use Settings
to switch between Chronicle and Modern. Enable friendly nameplates in the game
if you want outdoor recognition badges.

Ratings and notes persist within a client-build partition. Recent observations
clear on reload. Updating the client build currently starts a fresh partition.

## Feedback and source

Report bugs through [Issues](https://github.com/Topping/Companion-Chronicle/issues),
including the client build, steps to reproduce and any Lua error.

This repository holds exported release snapshots. Development takes place in a
separate private repository. Exported source and release automation are available
here under the [MIT license](LICENSE).
