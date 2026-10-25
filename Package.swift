// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Island",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Island",
            path: "Sources/Island",
            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
