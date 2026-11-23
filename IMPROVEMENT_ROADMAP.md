# Improvement roadmap

1. Protect campaign recovery and validate it with legacy and malformed save fixtures.
2. Exercise full host/join and reconnect scenarios, with particular attention to in-progress jobs, vehicle handoffs and duplicated reward prevention.
3. Run interactive passes for vehicle exits on slopes, casting and bite feedback, mowing from pickup through payout, docking, and skill purchase feedback. Prioritize failures that block those loops.
4. Establish repeatable GPU and CPU captures for the marina, residential streets and waterfront, with separate scene-load timing. Profile building detail, vegetation, shadows and replication before tuning.
5. Resolve export packaging for image data and verify a packaged launch. Use the measured rendering budget to tune existing façade details, street fixtures and waterfront materials.
6. Build longer-term goals around existing repeatable mowing and fishing activities. Prototype rotating contracts and equipment goals before considering traffic or pedestrians.

The follow-up verified the Windows PCK, added loopback coverage for boat helm handoff, and verified vehicle-exit clearance in a physics fixture. The next gameplay pass is a live session with two players, including vessel boarding, docking, and host-only mowing through payout. Capture GPU frame timings on target hardware before choosing town rendering changes. Use an economy playthrough across several in-game days before tuning rewards or adding new contracts.
