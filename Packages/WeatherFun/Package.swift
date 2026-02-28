// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "WeatherFun",
    platforms: [.iOS(.v15)],
    products: [.library(name: "WeatherFun", targets: ["WeatherFun"])],
    targets: [
        .target(
            name: "WeatherFun",
            resources: [.process("Resources")]
        )
    ]
)
