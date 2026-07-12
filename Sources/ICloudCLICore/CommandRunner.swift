import Foundation

public struct CommandRunner: Sendable {
    private let parser: CLIParser
    private let remindersClient: any ReminderEventKitClient
    private let output: @Sendable (String) -> Void
    private let errorOutput: @Sendable (String) -> Void

    public init(
        parser: CLIParser = CLIParser(),
        remindersClient: any ReminderEventKitClient = SystemReminderEventKitClient(),
        output: @escaping @Sendable (String) -> Void = { print($0) },
        errorOutput: @escaping @Sendable (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) {
        self.parser = parser
        self.remindersClient = remindersClient
        self.output = output
        self.errorOutput = errorOutput
    }

    @discardableResult
    public func run(arguments: [String]) -> Int32 {
        do {
            switch try parser.parse(arguments: arguments) {
            case .help:
                output(CLIHelp.root())
                return 0
            case .version:
                output(CLIHelp.version)
                return 0
            case .cacheRead(let options):
                let command = options.command ?? ""
                let envelope = try CacheWatchStore(outputDirectory: options.outputDirectory).read(command: command)
                output(try render(envelope, format: options.format))
                return 0
            case .cacheStatus(let options):
                let status = try CacheWatchStore(outputDirectory: options.outputDirectory).status()
                output(try render(status, format: options.format))
                return 0
            case .cloudTabsProbe(let options):
                let report = CloudTabsProbe(safariDirectory: options.safariDirectory).probe()
                output(try render(report, format: options.format))
                return 0
            case .contactsList(let options):
                let database = AddressBookStoreResolver(defaultDatabase: options.addressBookDatabase).database()
                let contacts = try LocalSQLiteInventoryReader(database: database).contacts(search: options.search, limit: options.limit, includeNotes: options.includeNotes)
                output(try render(contacts, format: options.format))
                return 0
            case .devicesList(let options):
                let devices = try ICloudDevicesReader(cacheFile: options.cacheFile).listDevices()
                output(try render(devices, format: options.format))
                return 0
            case .driveContainers(let options):
                let containers = try ICloudDriveInventoryReader(rootDirectory: options.rootDirectory).listContainers(sortBy: options.sortBy)
                output(try render(containers, format: options.format))
                return 0
            case .driveList(let options):
                let files = try ICloudDriveInventoryReader(rootDirectory: options.rootDirectory).listFiles(path: options.path, depth: options.depth)
                output(try render(files, format: options.format))
                return 0
            case .focusStatus(let options):
                let status = try FocusStatusReader(focusDirectory: options.focusDirectory).readStatus()
                output(try render(status, format: options.format))
                return 0
            case .handoffList(let options):
                let activities = try HandoffActivityReader(handoffDirectory: options.handoffDirectory).listActivities(limit: options.limit)
                output(try render(activities, format: options.format))
                return 0
            case .mapsFavorites(let options):
                let places = try LocalSQLiteInventoryReader(database: options.store).mapFavorites()
                output(try render(places, format: options.format))
                return 0
            case .mapsRecents(let options):
                let places = try LocalSQLiteInventoryReader(database: options.store).mapRecents(limit: options.limit)
                output(try render(places, format: options.format))
                return 0
            case .messagesConversations(let options):
                let conversations = try LocalSQLiteInventoryReader(database: options.chatDatabase).messageConversations(limit: options.limit)
                output(try render(conversations, format: options.format))
                return 0
            case .messagesRecent(let options):
                let messages = try LocalSQLiteInventoryReader(database: options.chatDatabase).recentMessages(confirmSensitive: options.confirmSensitive, includeBody: options.includeBody, since: options.since, limit: options.limit)
                output(try render(messages, format: options.format))
                return 0
            case .metadata(let command, let options):
                output(try runMetadata(command: command, options: options))
                return 0
            case .newsHistory(let options):
                let articles = try LocalSQLiteInventoryReader(database: options.store).newsHistory(since: options.since, limit: options.limit)
                output(try render(articles, format: options.format))
                return 0
            case .newsTopics(let options):
                let topics = try LocalSQLiteInventoryReader(database: options.store).newsTopics()
                output(try render(topics, format: options.format))
                return 0
            case .notesList(let options):
                let notes = try LocalSQLiteInventoryReader(database: options.notesStore).notes(folder: options.folder, modifiedSince: options.modifiedSince, includeBody: options.includeBody)
                output(try render(notes, format: options.format))
                return 0
            case .photosList(let options):
                let photos = try PhotosInventoryReader(photosLibraryDirectory: options.photosLibrary).listPhotos(limit: options.limit)
                output(try render(photos, format: options.format))
                return 0
            case .photosScreenshots(let options):
                let screenshots = try PhotosInventoryReader(screenshotsDirectory: options.screenshotsDirectory).listScreenshots()
                output(try render(screenshots, format: options.format))
                return 0
            case .providersList(let format):
                output(try render(ProviderRegistry.manifest, format: format))
                return 0
            case .remindersList(let options):
                let reminders = if options.degradedPrivateStore {
                    try LocalSQLiteInventoryReader(database: options.store).reminders(list: options.list, dueBefore: options.dueBefore, dueAfter: options.dueAfter, includeCompleted: options.includeCompleted)
                } else {
                    try EventKitRemindersProvider(client: remindersClient).reminders(list: options.list, dueBefore: options.dueBefore, dueAfter: options.dueAfter, includeCompleted: options.includeCompleted, limit: options.limit)
                }
                output(try render(reminders, format: options.format))
                return 0
            case .remindersLists(let options):
                let lists = if options.degradedPrivateStore {
                    try LocalSQLiteInventoryReader(database: options.store).reminderLists()
                } else {
                    try EventKitRemindersProvider(client: remindersClient).lists(limit: options.limit)
                }
                output(try render(lists, format: options.format))
                return 0
            case .remindersAuthorization(let format):
                output(try render(EventKitRemindersProvider(client: remindersClient).authorization(), format: format))
                return 0
            case .safariBookmarks(let options):
                let directory = SafariProfileDirectoryResolver().directory(baseDirectory: options.safariDirectory, profile: options.profile)
                let bookmarks = try SafariBookmarksReader(safariDirectory: directory).readBookmarks()
                output(try render(bookmarks, format: options.format))
                return 0
            case .safariFrequentlyVisited(let options):
                let directory = SafariProfileDirectoryResolver().directory(baseDirectory: options.safariDirectory, profile: options.profile)
                let sites = try SafariFrequentlyVisitedReader(safariDirectory: directory).readSites(limit: options.limit)
                output(try render(sites, format: options.format))
                return 0
            case .safariHistory(let options):
                let database = safariHistoryDatabase(for: options)
                let history = try LocalSQLiteInventoryReader(database: database).safariHistory(confirmSensitive: options.confirmSensitive, since: options.since, until: options.until, limit: options.limit, redactURLs: options.redactURLs)
                output(try render(history, format: options.format))
                return 0
            case .safariReadingList(let options):
                let directory = SafariProfileDirectoryResolver().directory(baseDirectory: options.safariDirectory, profile: options.profile)
                let items = try SafariBookmarksReader(safariDirectory: directory).readReadingList()
                output(try render(items, format: options.format))
                return 0
            case .safariTabs(let options):
                let directory = SafariProfileDirectoryResolver().directory(baseDirectory: options.safariDirectory, profile: options.profile)
                let tabs = try SafariTabsReader(safariDirectory: directory).readTabs(source: options.source)
                output(try render(tabs, format: options.format))
                return 0
            case .shortcutsList(let options):
                let shortcuts = try ShortcutsInventoryReader(shortcutsDirectory: options.shortcutsDirectory).listShortcuts(namePattern: options.namePattern)
                output(try render(shortcuts, format: options.format))
                return 0
            case .storageStatus(let options):
                let status = try ICloudStorageStatusReader(cacheFile: options.cacheFile).readStatus()
                output(try render(status, format: options.format))
                return 0
            case .walletPasses(let options):
                let passes = try WalletPassesReader(passesDirectory: options.passesDirectory).listPasses(type: options.type, activeOnly: options.activeOnly)
                output(try render(passes, format: options.format))
                return 0
            case .watch(let options):
                let store = CacheWatchStore(outputDirectory: options.outputDirectory)
                repeat {
                    let status = try store.refresh(commands: options.commands)
                    output(try render(status, format: .json))
                    if options.once { break }
                    Thread.sleep(forTimeInterval: TimeInterval(options.intervalSeconds))
                } while true
                return 0
            }
        } catch {
            errorOutput(error.localizedDescription)
            return 1
        }
    }

    private func safariHistoryDatabase(for options: SafariHistoryOptions) -> URL {
        guard let profile = options.profile?.trimmingCharacters(in: .whitespacesAndNewlines),
            !profile.isEmpty,
            profile.lowercased() != "all"
        else {
            return options.historyDatabase
        }
        let baseDirectory = options.historyDatabase.deletingLastPathComponent()
        return SafariProfileDirectoryResolver()
            .directory(baseDirectory: baseDirectory, profile: profile)
            .appendingPathComponent(options.historyDatabase.lastPathComponent)
    }

    private func runMetadata(command: MetadataCommand, options: MetadataOptions) throws -> String {
        switch command {
        case .accountStatus:
            let status = try AccountStatusReader(cacheFile: options.store ?? LocalMetadataStoreReader.defaultStore(for: command)).readStatus()
            return try render(status, format: options.format)
        case .backupStatus:
            let status = try BackupStatusReader(cacheFile: options.store ?? LocalMetadataStoreReader.defaultStore(for: command)).readStatus()
            return try render(status, format: options.format)
        case .familyStatus:
            let status = try FamilyStatusReader(cacheFile: options.store ?? LocalMetadataStoreReader.defaultStore(for: command)).readStatus()
            return try render(status, format: options.format)
        case .permissionsDoctor:
            return try render(PermissionsDoctor().diagnose(), format: options.format)
        case .snapshot:
            let report = SnapshotBuilder().build(options: options)
            let rendered = try render(report, format: options.format)
            if let output = options.output {
                try rendered.write(to: output, atomically: true, encoding: .utf8)
            }
            return rendered
        case .driveStatus:
            let reader = ICloudDriveInventoryReader(rootDirectory: options.rootDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"))
            return try render(try reader.syncStatus(path: options.path, limit: options.driveStatusLimit), format: options.format)
        case .driveErrors:
            let reader = ICloudDriveInventoryReader(rootDirectory: options.rootDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"))
            return try render(try reader.errorFiles(path: options.path, limit: options.limit), format: options.format)
        case .driveShared:
            let reader = ICloudDriveInventoryReader(rootDirectory: options.rootDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"))
            return try render(try reader.sharedItems(path: options.path, limit: options.limit), format: options.format)
        case .driveRecents:
            let reader = ICloudDriveInventoryReader(rootDirectory: options.rootDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"))
            return try render(try reader.recentFiles(since: options.since, limit: options.limit), format: options.format)
        case .tagsList:
            let reader = FinderTagsReader(preferencesFile: options.store ?? FinderTagsStoreResolver().resolvedPreferencesFile(), driveRoot: options.rootDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"))
            return try render(try reader.listTags(), format: options.format)
        case .taggedItems:
            guard let tag = options.tag else { throw CLIParseError.missingValue("--tag") }
            let reader = FinderTagsReader(preferencesFile: options.store ?? FinderTagsStoreResolver().resolvedPreferencesFile(), driveRoot: options.rootDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"))
            return try render(try reader.items(tag: tag, path: options.path, limit: options.limit), format: options.format)
        default:
            let store = options.store ?? LocalMetadataStoreReader.defaultStore(for: command)
            let rows = try LocalMetadataStoreReader(database: store).rows(for: command, options: options)
            return try render(rows, format: options.format)
        }
    }

    public func render(_ tabs: [SafariTab], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(tabs), as: UTF8.self)
        case .text:
            return tabs
                .map { tab in
                    if let title = tab.title {
                        return "\(title) - \(tab.url)"
                    }
                    return tab.url
                }
                .joined(separator: "\n")
        }
    }

    public func render<T: Encodable>(_ values: [T], format: OutputFormat) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(values), as: UTF8.self)
        switch format {
        case .json:
            return json
        case .text:
            return json
        }
    }

    public func render<T: Encodable>(_ value: T, format: OutputFormat) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    public func render(_ manifest: ProviderManifest, format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(manifest), as: UTF8.self)
        case .text:
            let providers = manifest.providers.map { provider in
                "\(provider.id) \(provider.displayName) maturity=\(provider.maturity.rawValue) source=\(provider.sourceKind.rawValue) access=\(provider.accessMode.rawValue) sensitivity=\(provider.sensitivity.rawValue) default-polling=\(provider.defaultPolling) commands=\(provider.commands.joined(separator: ",")) capabilities=\(provider.capabilities.joined(separator: ",")) permissions=\(provider.permissionExpectations.joined(separator: ","))"
            }
            return (["Provider manifest \(manifest.schemaVersion)"] + providers).joined(separator: "\n")
        }
    }

    public func render(_ rows: [MetadataRow], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(rows), as: UTF8.self)
        case .text:
            return rows.map { row in
                let fields = row.fields
                    .sorted { $0.key < $1.key }
                    .compactMap { key, value in value.stringValue.map { "\(key)=\($0)" } }
                    .joined(separator: " ")
                return fields.isEmpty ? row.kind : "\(row.kind): \(fields)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ report: SnapshotReport, format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(report), as: UTF8.self)
        case .text:
            return report.entries.map { entry in
                let status = entry.ok ? "ok" : "error"
                return "\(entry.command): \(status) - \(entry.summary)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ probes: [PermissionProbe], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(probes), as: UTF8.self)
        case .text:
            return probes.map { "\($0.command): \($0.status) - \($0.hint)" }.joined(separator: "\n")
        }
    }


    public func render(_ bookmarks: [SafariBookmark], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(bookmarks), as: UTF8.self)
        case .text:
            return bookmarks.map { bookmark in
                let prefix = bookmark.folderPath.isEmpty ? "" : "[\(bookmark.folderPath)] "
                if let title = bookmark.title { return "\(prefix)\(title) - \(bookmark.url)" }
                return "\(prefix)\(bookmark.url)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ items: [SafariReadingListItem], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(items), as: UTF8.self)
        case .text:
            return items.map { item in
                if let title = item.title { return "\(title) - \(item.url)" }
                return item.url
            }.joined(separator: "\n")
        }
    }

    public func render(_ sites: [SafariFrequentlyVisitedSite], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(sites), as: UTF8.self)
        case .text:
            return sites.map { site in
                if let title = site.title { return "#\(site.rank) \(title) - \(site.url)" }
                return "#\(site.rank) \(site.url)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ files: [ICloudDriveFile], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(files), as: UTF8.self)
        case .text:
            return files.map { file in
                let size = file.sizeBytes.map { "\($0) bytes" } ?? "evicted"
                return "[\(file.iCloudStatus.rawValue)] \(file.path) (\(size))"
            }.joined(separator: "\n")
        }
    }

    public func render(_ containers: [ICloudDriveContainer], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(containers), as: UTF8.self)
        case .text:
            return containers.map { container in
                let size = container.sizeBytes.map { "\($0) bytes" } ?? "unknown size"
                return "\(container.displayName) [\(container.bundleId)] - \(size)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ shortcuts: [ShortcutEntry], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(shortcuts), as: UTF8.self)
        case .text:
            return shortcuts.map { shortcut in
                let input = shortcut.acceptsInput ? "accepts input" : "no input"
                return "\(shortcut.name) - \(shortcut.actionCount) actions, \(input)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ status: ICloudStorageStatus, format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(status), as: UTF8.self)
        case .text:
            let used = Double(status.usedBytes) / 1_000_000_000
            let total = Double(status.totalBytes) / 1_000_000_000
            let available = Double(status.availableBytes) / 1_000_000_000
            let account = status.accountEmail ?? "unknown account"
            return String(format: "iCloud storage: %.1f GB used of %.1f GB, %.1f GB available (%@)", used, total, available, account)
        }
    }

    public func render(_ status: FocusStatus, format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(status), as: UTF8.self)
        case .text:
            guard let active = status.activeFocus else { return "Focus: none" }
            if let endsAt = status.endsAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                return "Focus: \(active) (until \(formatter.string(from: endsAt)))"
            }
            return "Focus: \(active)"
        }
    }

    public func render(_ devices: [ICloudDevice], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(devices), as: UTF8.self)
        case .text:
            return devices.map { device in
                let current = device.isCurrentDevice ? " current" : ""
                let os = device.osVersion.map { " (\($0))" } ?? ""
                return "\(device.name) - \(device.model)\(os)\(current)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ passes: [WalletPass], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(passes), as: UTF8.self)
        case .text:
            return passes.map { pass in
                let date = pass.relevantDate.map { ISO8601DateFormatter().string(from: $0) } ?? "no relevant date"
                return "\(pass.passType.rawValue): \(pass.organizationName) - \(pass.description) (\(date))"
            }.joined(separator: "\n")
        }
    }

    public func render(_ activities: [HandoffActivity], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(activities), as: UTF8.self)
        case .text:
            return activities.map { activity in
                let title = activity.title.map { " - \($0)" } ?? ""
                return "\(activity.deviceName): \(activity.appName) [\(activity.activityType)]\(title)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ report: CloudTabsProbeReport, format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(report), as: UTF8.self)
        case .text:
            var lines = [
                "Cloud tabs store: \(report.databasePath)",
                "Exists: \(report.exists ? "yes" : "no")",
                "Readable: \(report.readable ? "yes" : "no")",
            ]
            if let sizeBytes = report.sizeBytes {
                lines.append("Size: \(sizeBytes) bytes")
            }
            if let failureMode = report.failureMode {
                lines.append("Failure mode: \(failureMode)")
            }
            lines.append("Recommended default: \(report.recommendedDefault)")
            lines.append("Permission expectation: \(report.permissionExpectation)")
            return lines.joined(separator: "\n")
        }
    }
}
