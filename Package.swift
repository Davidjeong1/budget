// swift-tools-version: 5.9
import PackageDescription

// The message-recognition logic lives in its own package with no UIKit/SwiftUI dependency so it
// can be unit tested on any machine, and so the app, the App Intent and the share extension all
// parse messages exactly the same way.
let package = Package(
    name: "LedgerParser",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LedgerParser", targets: ["LedgerParser"]),
    ],
    targets: [
        .target(name: "LedgerParser"),
        .testTarget(name: "LedgerParserTests", dependencies: ["LedgerParser"]),
    ]
)
