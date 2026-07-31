// swift-tools-version: 5.9
import PackageDescription

// Ledger domain types with no UIKit/SwiftUI dependency, so they can be unit tested on any machine.
let package = Package(
    name: "LedgerCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LedgerCore", targets: ["LedgerCore"]),
    ],
    targets: [
        .target(name: "LedgerCore"),
        .testTarget(name: "LedgerCoreTests", dependencies: ["LedgerCore"]),
    ]
)
