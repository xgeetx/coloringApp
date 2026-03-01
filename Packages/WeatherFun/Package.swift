// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "WeatherFun",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "WeatherFun", targets: ["WeatherFun"]),
        .library(name: "WeatherFunCore", targets: ["WeatherFunCore"])
    ],
    targets: [
        .target(
            name: "WeatherFunCore"
        ),
        .target(
            name: "WeatherFun",
            dependencies: ["WeatherFunCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WeatherFunTests",
            dependencies: ["WeatherFunCore"]
        )
    ]
)
