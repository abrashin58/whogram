// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhogramTDLibSmoke",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Swiftgram/TDLibKit", revision: "602779afb3449ba481b33719e91f5154f5de80b6")
    ],
    targets: [
        .executableTarget(name: "WhogramTDLibSmoke", dependencies: [.product(name: "TDLibKit", package: "TDLibKit")])
    ]
)
