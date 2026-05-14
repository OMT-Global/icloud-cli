# Issue work plan

Reviewed 19 open issues from `open-issues.json`.

## Groups

- Safari local browser metadata: #20 Safari bookmarks/reading list, #25 Safari history, #36 frequently visited sites.
- Local iCloud inventory: #18 photos/screenshots, #19 Drive files, #21 Notes titles, #22 storage quota, #23 cache/watch mode, #24 Reminders, #28 Contacts, #32 app containers.
- Apple ecosystem state: #27 Shortcuts, #29 Focus, #30 Handoff, #31 devices, #33 Maps, #34 News, #35 Wallet.
- High-sensitivity communication data: #26 Messages.

## Selected group

Selected the Safari local browser metadata group, but deliberately limited implementation to the lower-risk durable surfaces: #20 bookmarks/reading list and #36 frequently visited sites. Safari history (#25) remains separate because it needs an explicit opt-in flag and stronger redaction defaults.
