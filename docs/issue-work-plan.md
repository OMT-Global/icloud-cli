# Issue work plan

Reviewed the remaining open issues after the Safari metadata PR.

## Groups

- iCloud Drive filesystem metadata: #19 Drive file inventory and #32 app iCloud container inventory.
- Local app/private databases: #21 Notes, #24 Reminders, #28 Contacts.
- Device/availability state: #29 Focus, #30 Handoff, #31 devices.
- High-sensitivity activity/content: #25 Safari history, #26 Messages, #33 Maps, #34 News, #35 Wallet.

## Selected group

Selected the iCloud Drive filesystem metadata group (#19 and #32). It is coherent, testable with synthetic directories, and lower-risk than message/history/location surfaces because it reads metadata only and never file contents.
