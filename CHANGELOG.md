# Changelog

## 0.1.0

- Rebrand the addon to Companion Chronicle, packaged as CompanionChronicle.
  Use `/companionchronicle`; `/cchron` is the short alias. Development data is
  disposable; no migration from Allies is planned.

- Chronicle uses consistent first-name/surname typography, simplified uppercase
  page headings and the single dedication “Names worth keeping.”

- Chronicle client polish: page actions raised above the lower parchment edge,
  with history space reserved; stitched leather bookmarks replace square tabs.

- Immersive Chronicle is the default appearance: textured leather-bound book,
  parchment pages, a two-column index and native quest typography. Modern remains
  available in Settings. Appearance persists without changing player records.
- Shared controller separates ratings, Undo, note drafts and settings from both
  native views. Switching preserves drafts, selection and the visible memory;
  view-owned font measurement prevents fixed-height note clipping.
- Docker simulator verification is now exercised alongside static and packaging
  gates, including both appearances, large histories and headless actions.

- Private chat recognition markers and group reunion reminders, independently
  switchable in Allies settings. Group reminders include a short saved note.

- Chat menus support Forever full names and missing realms using the sender's
  GUID; later unit encounters share the same personal history and indicators.

- Field journal skin: generated leather/parchment, dark ink, quest fonts and
  selected-person/tab indicators across journal, notes and settings.

- Friendly/Unfriendly actions save silently; optional note prompting in Allies
  Settings defaults Off. Undo last is available in the player menu.

- Generated positive-rep and ally textures at 24 UI units on nameplates and target frames.

- Compact journal: explicit rep and location, content-sized entries, direct note
  editing; full metadata and deletion controls available through Details.

- Forever beta test target: Interface 16001; explicit beta deployment directory.
- Targeting a player only refreshes recognition; it does not record an encounter.

- Allies POC: personal +/− reputation, optional notes, Undo and explicit ally status.
- Native player menu actions; on-demand Recent and Remembered views via `/allies`.
- Bounded session-only context history, original-context preservation and persistent personal records.
- Private friendly nameplate badges, target indicator and tooltip summaries.
- Exact-client-build data isolation for the POC while Forever identification remains unverified.
- Supplemental model/interaction regressions; live acceptance and container simulation pending.
