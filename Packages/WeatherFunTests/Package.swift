// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "WeatherFunTests",
    platforms: [.iOS(.v15), .macOS(.v12)],
    dependencies: [
        .package(path: "../WeatherFun")
    ],
    targets: [
        .testTarget(
            name: "WeatherFunCoreTests",
            dependencies: [
                .product(name: "WeatherFunCore", package: "WeatherFun")
            ]
        )
    ]
)
