import Foundation

public struct CommandRunner: Sendable {
    private let parser: CLIParser
    private let output: @Sendable (String) -> Void
    private let errorOutput: @Sendable (String) -> Void

    public init(
        parser: CLIParser = CLIParser(),
        output: @escaping @Sendable (String) -> Void = { print($0) },
        errorOutput: @escaping @Sendable (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) {
        self.parser = parser
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
            case .safariTabs(let options):
                let tabs = try SafariTabsReader(safariDirectory: options.safariDirectory).readTabs(source: options.source)
                output(try render(tabs, format: options.format))
                return 0
            }
        } catch {
            errorOutput(error.localizedDescription)
            return 1
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
}
