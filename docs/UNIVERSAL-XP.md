# Universal XP and skill tree

During play, press **K** or the controller Back button to open the tree. Escape, Back, or the Close button returns to play. Select a branch, pan or zoom its prerequisite graph, select a rank, then purchase it with a skill point. The host keeps simulating the game while the menu is open.

## Current integration

[Progression and economy](systems/PROGRESSION-ECONOMY.md) explains the shared advancement, economy and save boundaries. See [Game identity](GAME-IDENTITY.md) for future research and activity terminology.

| Source under godot-cove | Integration |
| --- | --- |
| game_world.gd, river_stock.gd, crew_play.gd | Local fishing simulation owns species selection and the landing transition. A guest can also help net a host-verified catch. |
| river_backpack.gd, progression_screen.tscn, progression_screen.gd, skill_hex.gd | The HUD uses the backpack hotbar offset. A separate canvas layer hosts the tree and nonblocking level banner. |
| shannon_job.gd, lawn_mower.gd | The mower emits a signal for a newly cut tuft. Shannon verifies the active route and turn-in. The base game limits this job to the host. Commercial Contractor unlocks an optional second daily route covering two mowing areas. |
| game_campaign.gd, game_campaign_data.gd | The host advances boat motion, contracts, dock discovery, power and payouts. Three additional contracts use the existing survey and freight activities. |
| marina_cars.gd, marina_car.gd | The host steps each occupied car. Travel XP, steering and collision recovery use the driver’s own ranks. |
| multiplayer_session.gd, game_ledger.gd | Registered peers request purchases. The host saves progression in the active solo or multiplayer campaign and sends each peer its own summary. |
| progression.gd, progression_catalog.gd, progression_skills.json | The reward registry, level curve and data-driven catalog define skill ranks, level gates, numeric effects and graph positions. |

## Progression and persistence

Each level grants one point. The level-50 cap clamps cumulative XP to the sum of the first 49 thresholds. Level and points are derived from total XP and purchased ranks. Equipment and shared cash retain their existing purchase rules.

A versioned profile stores XP, ranks and rewarded event IDs inside the host campaign. A per-installation credential identifies a returning player independently of the ephemeral ENet peer number. Two simultaneous clients sharing exactly the same credential receive separate progress, with a temporary profile for the duplicate. Use separate user-data directories to test persistent identities. Moving to another host campaign starts with that campaign’s own records.

Travel uses displacement across the host simulation step, the current driver or captain, applied propulsion and a speed bound. Idling and position changes outside the step give no travel credit. Every 500 m awards XP. Mowing counts newly cut eligible grass in batches of 100 and awards completion once per daily contract. Job XP goes to verified contributors on turn-in, including qualifying freight captains. The event ledger survives reload. The client sends a skill ID and the rank it saw; the host validates the expected rank, prerequisites, gate, points and cap.

## Skill availability

The tree contains all 42 proposed definitions. Twenty-nine have working effects. Select a disabled skill to see the missing mechanic. The unavailable hooks are:

- **Lawn Care** — Efficient Operator needs mower fuel consumption.
- **Driving** — Fuel Saver and Mechanics Touch need a road-vehicle fuel or wear model. Professional Driver and Transport Master need road delivery contracts. The current freight jobs run between river landings. Road Veteran instead requires Smooth Driver and improves acceleration immediately after a collision.
- **Business** — Efficient Management, Entrepreneur and Business Tycoon need operating expenses and business ownership. Existing shore plot ownership is separate.
- **Exploration** — Endurance, Athletic and Outdoorsman need stamina consumption. Treasure Hunter needs a collectible registry. Town Legend depends on these missing activities.

Standalone guest catches and guest-controlled dive retrieval use client-reported results in the base game. Those reports preserve the existing activity and economy but cannot grant progression by themselves. Host catches and a guest helping net a host catch can earn fishing XP. Daily mowing is available in solo and to the multiplayer host. First-time exploration currently means a verified landing by boat. Fishing and boat mastery grant +10% activity XP. Landscaping mastery grants +10% mowing XP. One-rank contract unlocks grant a distinct contract.

## Verification

Run the following from the worktree with Godot 4.7.2. Set the engine variable to the console executable. Use an isolated temporary APPDATA directory for each run on Windows. The integration tests require a user-data path containing houseboat-xp-.

~~~powershell
& $engine --headless --path godot-cove --import
foreach ($test in 'verify_progression', 'verify_progression_game', 'verify_progression_network') {
    $env:APPDATA = Join-Path $env:TEMP ('houseboat-xp-' + [guid]::NewGuid())
    New-Item -ItemType Directory $env:APPDATA | Out-Null
    & $engine --headless --path godot-cove -s "res://$test.gd"
    if ($LASTEXITCODE) { throw "$test failed" }
}
~~~

The core test checks thresholds, multi-level awards, cap behavior, duplicate events, skill points, gates, rank caps and the catalog graph. The gameplay test loads a pre-progression campaign, opens all six branches, purchases a skill, saves and reloads it, checks boat distance bounds and cuts a daily route with the mower’s real trimming function. The network test creates an ENet host and two guest endpoints on loopback and checks private snapshots, a purchase and reconnect.

For a manual playtest, host a crew session and join from a second installation. Finish Shannon’s route on the host, have a guest pilot a boat for 500 m, then compare XP and buy a rank on each screen. Rejoin and verify that HUD notifications only appear for new rewards. Repeat with a gamepad and at the target display resolutions. The supplied screenshot uses earned progression in an isolated preview profile.
