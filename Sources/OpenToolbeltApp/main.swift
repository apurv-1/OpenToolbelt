import Foundation

#if DEBUG
let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--snapshot"), flag + 1 < arguments.count {
    // --home points the scan at another directory, such as the demo home
    // from scripts/demo-home.py, so screenshots carry no real data.
    let home = arguments.firstIndex(of: "--home").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
    Snapshot.run(to: URL(fileURLWithPath: arguments[flag + 1]),
                 home: home.map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser)
    exit(0)
}
if let flag = arguments.firstIndex(of: "--promo"), flag + 1 < arguments.count {
    let home = arguments.firstIndex(of: "--home").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
    Promo.render(to: URL(fileURLWithPath: arguments[flag + 1]),
                 home: home.map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser)
    exit(0)
}
#endif

OpenToolbeltApp.main()
