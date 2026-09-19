# Changelog

## 0.2.1

Companion Chronicle for WoW Forever 1.60.1 (Interface 16001).

- Add a custom journal icon to the in-game addon list and a circular minimap
  button. Click the button to open or close the journal; drag it around the
  minimap to choose a position that is saved across sessions.
- Keep `/companionchronicle` and `/cchron` as alternate ways to open the journal.

## 0.2.0

Companion Chronicle for WoW Forever 1.60.1 (Interface 16001).

- Correct how Forever's two-part player names are resolved in player menus and
  chat, and keep records tied to verified identities. Existing records are
  repaired when a matching full name and GUID are observed.
- Improve journal selection, note editing, history layout and Settings behavior
  in both Chronicle and Modern appearances.
- Add reproducible, high-resolution addon and component previews using the
  addon UI with fictional sample entries. Refresh the CurseForge description
  and include the Chronicle page screenshot.

## 0.1.0

First public release of Companion Chronicle for WoW Forever beta 1.60.1
(Interface 16001).

- Record friendly and unfriendly encounters from supported player menus, keep
  optional notes, mark allies, and undo the last rating.
- Browse remembered players and recent encounters in the illustrated Chronicle
  journal or compact Modern layout. Open with `/companionchronicle` or `/cchron`.
- Recognize remembered players through private chat markers, group reminders,
  tooltips, target indicators and supported friendly nameplates.
- Switch appearance and recognition options in Settings, with explicit On/Off
  choices and clear selection indicators. Fix recursive hover callbacks when
  selecting settings on the Forever client.
- Improve note-editor contrast in both appearances and use measured, paginated
  history layouts with separated entry details and compact note previews.
- Keep personal records local and partitioned by client build. Recent encounters
  are session-only; targeting a player does not record an encounter.

Known limitations:

- On tested Forever beta build 1.60.1.69913, saved players and notes disappear
  after `/reload`. This is being treated as a client SavedVariables regression
  pending a Blizzard fix; journal data is unreliable on this build.
- Client testing is partial. Combat, taint, server-dependent behavior and the
  latest visual fixes still need real-client validation. Headless checks do not
  establish client persistence or rendering correctness.
- Compatibility with other clients is not claimed. Development data is
  disposable, and migrations from the earlier Allies prototype are not provided.
