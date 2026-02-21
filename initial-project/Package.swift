// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacNTFS",
    targets: [
        .executableTarget(
            name: "MacNTFS",
            dependencies: ["Shared"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__entitlements",
                    "-Xlinker", "Sources/MacNTFS/Resources/MacNTFS.entitlements"
                ])
            ]
        ),
        .executableTarget(
            name: "MacNTFSHelper",
            dependencies: ["Shared"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MacNTFSHelper/Resources/Info.plist",
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__entitlements",
                    "-Xlinker", "Sources/MacNTFSHelper/Resources/MacNTFSHelper.entitlements"
                ])
            ]
        ),
        .target(
            name: "Shared"
        )
    ]
)
