# Issue work plan

Reviewed the remaining open issues after the Drive metadata PR.

## Groups

- Ready medium-risk data commands: #21 Notes titles, #22 storage quota status, #23 cache/watch mode.
- Local automation metadata: #27 Shortcuts inventory.
- High-sensitivity content/activity surfaces: #18 Photos, #25 Safari history, #26 Messages, #33 Maps, #34 News, #35 Wallet.
- Device/status surfaces: #29 Focus, #30 Handoff, #31 connected devices.

## Selected group

Selected #27 Shortcuts inventory as the next low/medium-risk pass. It is coherent, read-only, testable with synthetic `.shortcut` bundles, and avoids executing Shortcuts or reading private content databases.
