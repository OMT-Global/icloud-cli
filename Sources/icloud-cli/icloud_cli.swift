import Foundation
import ICloudCLICore

@main
struct ICloudCLI {
    static func main() {
        let status = CommandRunner().run(arguments: CommandLine.arguments)
        if status != 0 {
            exit(status)
        }
    }
}
