// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TraceFun",
    platforms: [.iOS(.v15)],
    products: [.library(name: "TraceFun", targets: ["TraceFun"])],
    targets: [.target(name: "TraceFun")]
)
