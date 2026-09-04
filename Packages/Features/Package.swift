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
        // archinit:products-end
    ],
    dependencies: [
        .package(url: "https://github.com/hiramvazquez/AppFoundation.git", from: "1.2.0"),
        .package(url: "https://github.com/hiramvazquez/CoreNetworking.git", from: "1.0.0"),
        .package(path: "../Platform")
    ],
    targets: [
        // archinit:features-begin
        // archinit:features-end
    ]
)
