// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiquidGlassExample",
    platforms: [.iOS("17")],
    products: [
        .library(
            name: "LiquidGlassExample"
        )
    ]
)
