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
        .target(
            name: "WhispNotesLibrary",
            path: "Sources",
            exclude: ["AppMain"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),
        .executableTarget(
            name: "swift-whispnotes",
            dependencies: ["WhispNotesLibrary"],
            path: "Sources/AppMain"
        ),
        .testTarget(
            name: "swift-whispnotesTests",
            dependencies: ["WhispNotesLibrary"],
            path: "Tests/swift-whispnotesTests"
        )
    ]
)
