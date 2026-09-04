// swift-tools-version: 6.2
import PackageDescription

// Manifiesto reescrito por `archinit --multi` (PRD-AF-10) con su forma final — empezó
// como el manifiesto mínimo de la sección «Arranque» de PRD-AF-10.md (solo dependía de
// AppFoundation). `generate-feature` (modo multi) es la ÚNICA herramienta que edita esto
// después, y solo entre los markers `archinit:*` de abajo — nunca a mano.
let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Features",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // archinit:products-begin
        .library(name: "LoginFeature", targets: ["LoginFeature"]),
        // archinit:products-end
    ],
    dependencies: [
        .package(url: "https://github.com/hiramvazquez/AppFoundation.git", from: "1.2.0"),
        .package(url: "https://github.com/hiramvazquez/CoreNetworking.git", from: "1.0.0"),
        .package(path: "../Platform")
    ],
    targets: [
        // archinit:features-begin
        .target(
            name: "LoginFeature",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking"),
                .product(name: "Domain", package: "Platform"),
                .product(name: "Networking", package: "Platform"),
            ],
            path: "Sources/LoginFeature",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
            ]
        ),
        .testTarget(
            name: "LoginFeatureTests",
            dependencies: [
                "LoginFeature",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "CoreNetworkingTestSupport", package: "CoreNetworking"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/LoginFeatureTests",
            swiftSettings: swiftSettings
        ),
        // archinit:features-end
    ]
)
