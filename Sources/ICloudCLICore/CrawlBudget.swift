import Foundation

public enum CrawlState: String, Codable, Equatable, Sendable {
    case complete
    case partial
    case timeout
}

public struct CrawlBudget: Codable, Equatable, Sendable {
    public let scanLimit: Int
    public let wallClockLimitMilliseconds: Int

    public init(scanLimit: Int, wallClockLimitMilliseconds: Int) {
        self.scanLimit = max(1, scanLimit)
        self.wallClockLimitMilliseconds = max(1, wallClockLimitMilliseconds)
    }

    public static let defaultDrive = CrawlBudget(scanLimit: 5_000, wallClockLimitMilliseconds: 10_000)
    public static let defaultPolling = CrawlBudget(scanLimit: 2_000, wallClockLimitMilliseconds: 8_000)
}

public struct CrawlReport<Payload: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: String
    public let providerId: String
    public let state: CrawlState
    public let data: Payload
    public let scannedCount: Int
    public let resultCount: Int
    public let totalAvailable: Int?
    public let scanLimit: Int
    public let resultLimit: Int?
    public let wallClockLimitMilliseconds: Int
    public let elapsedMilliseconds: Int
    public let nextAction: String?

    public init(
        providerId: String,
        state: CrawlState,
        data: Payload,
        scannedCount: Int,
        resultCount: Int,
        totalAvailable: Int?,
        budget: CrawlBudget,
        resultLimit: Int? = nil,
        elapsedMilliseconds: Int,
        nextAction: String?
    ) {
        self.schemaVersion = "icloud-cli.crawl.v1"
        self.providerId = providerId
        self.state = state
        self.data = data
        self.scannedCount = scannedCount
        self.resultCount = resultCount
        self.totalAvailable = totalAvailable
        self.scanLimit = budget.scanLimit
        self.resultLimit = resultLimit
        self.wallClockLimitMilliseconds = budget.wallClockLimitMilliseconds
        self.elapsedMilliseconds = elapsedMilliseconds
        self.nextAction = nextAction
    }
}

public struct CrawlBudgetExceeded: Error, Equatable, Sendable {
    public let providerId: String
    public let state: CrawlState

    public init(providerId: String, state: CrawlState) {
        self.providerId = providerId
        self.state = state
    }
}
