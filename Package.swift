// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "swift-whispnotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "swift-whispnotes",
            targets: ["swift-whispnotes"])
    ],
    targets: [
        .executableTarget(
            name: "swift-whispnotes",
            path: "Sources",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)
