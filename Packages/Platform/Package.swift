// swift-tools-version: 6.2
import PackageDescription

// Generado por `archinit --multi` (PRD-AF-10). Domain: modelos/protocolos compartidos,
// solo Foundation. Un <Cap>Kit por --capability, un <Sdk>Adapters por --adapter — cada
// uno implementa un protocolo de Domain; `.archlint.yml` (raíz, R13) impide que un
// Kit/Adapter importe otro, o que una feature importe cualquiera de los dos.
let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Platform",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "CameraKit", targets: ["CameraKit"]),
        .library(name: "AnalyticsAdapters", targets: ["AnalyticsAdapters"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hiramvazquez/AppFoundation.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "Domain",
            path: "Sources/Domain",
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "ArchitectureLint", package: "AppFoundation")]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CameraKit",
            dependencies: ["Domain"],
            path: "Sources/CameraKit",
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "ArchitectureLint", package: "AppFoundation")]
        ),
        .target(
            name: "AnalyticsAdapters",
            dependencies: ["Domain"],
            path: "Sources/AnalyticsAdapters",
            swiftSettings: swiftSettings,
            plugins: [.plugin(name: "ArchitectureLint", package: "AppFoundation")]
        ),
    ]
)
