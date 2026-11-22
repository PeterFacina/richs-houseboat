# Godot source lookup for Codex

From the game folder on Windows, run:

```powershell
& ".\tools\godot-lookup\Find Godot Code.cmd" "crew_avatar pointing pitch"
& ".\tools\godot-lookup\Find Godot Code.cmd" "cove houseboat swell" -Trace
```

The default returns up to three project-relative file locations and short source excerpts. Use two or three specific words. Codex should open the smallest source range it needs around a promising line. Lookups run on the current checkout using standard Windows PowerShell. They require no Python, Git, Graphify installation, network connection, or Codex plugin.

`-Trace` adds up to two confirmed Graphify file links from the best result when `links.json` is present. Both endpoint files must match the hashes in the snapshot. Edited files are still searchable from live source, and stale links involving those files are skipped. If the index is absent, source lookup works on its own. To refresh graph links, export from a fresh Graphify snapshot with `Export-GodotLinks.ps1 -Snapshot <snapshot-folder>`.

## Give friends the same workflow

Extract the lookup ZIP into the folder that contains `godot-cove`. It adds `tools\godot-lookup`. Open the game folder as a Codex project and add the following paragraph to its existing `AGENTS.md`. If the file is absent, create it with this paragraph. For one chat, paste the paragraph into the chat instead.

> For unfamiliar Godot code on Windows, run `& ".\tools\godot-lookup\Find Godot Code.cmd" "<two or three source keywords>"` before broad source reads. Open only the source ranges needed to verify the results. Add `-Trace` for questions about relationships between scripts or scenes. If results are incomplete, use targeted source search. Skip lookup when the relevant path and symbol are already known.

The command reads source and the optional link index. The launcher uses a process-only PowerShell execution policy for the bundled script. It does not change machine or user settings.

## Snapshot comparison

On the current game, the default lookup returned 721 UTF-8 bytes across three queries, versus 1,105 bytes from the previous graph shortlist, a 35% decrease. It returned exact source lines for all three. With `-Trace` the same queries returned 980 bytes. These are command output sizes. End-to-end Codex tokens were outside this comparison.

| Query | Previous graph shortlist | Lookup | Lookup with trace |
| --- | ---: | ---: | ---: |
| Crew avatar pointing pitch | 410 B | 236 B | 329 B |
| Cove houseboat swell | 366 B | 187 B | 265 B |
| Fishing rig cast | 329 B | 298 B | 386 B |
