import Foundation

#if DEBUG
if let flag = CommandLine.arguments.firstIndex(of: "--snapshot"), flag + 1 < CommandLine.arguments.count {
    Snapshot.run(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
    exit(0)
}
#endif

OpenToolbeltApp.main()
