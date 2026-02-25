// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SpellingFun",
    platforms: [.iOS(.v15)],
    products: [.library(name: "SpellingFun", targets: ["SpellingFun"])],
    targets: [.target(name: "SpellingFun")]
)
