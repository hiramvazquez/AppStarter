// swift-tools-version: 6.2
import PackageDescription

// AppStarterKit — el paquete local que agrupa TODAS las Features de AppStarter. La app
// (`AppStarter`, target de xcodegen) es una cáscara fina: `@main`, `RootView` con el
// `Coordinator<AppRoute>`, y el `AppModule` (composition root) que registra los módulos
// de cada feature. Este paquete existe porque `generate-feature`/`archinit`/`archlint`
// son command plugins de SwiftPM — necesitan un `Package.swift` real sobre el que
// invocarse, y un `.xcodeproj` generado por xcodegen no lo ofrece por sí solo (ver
// docs/INFORME-INTEGRACION.md, fricción 1).
//
// Mismas swiftSettings que los paquetes que consume: `defaultIsolation(MainActor)`, los
// mismos upcoming features — así un tipo MainActor-isolated de AppFoundation se usa sin
// fricción desde este target.
let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "AppStarterKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppStarterKit",
            targets: ["AppStarterKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/hiramvazquez/AppFoundation.git", from: "1.1.0"),
        .package(url: "https://github.com/hiramvazquez/CoreNetworking.git", from: "1.0.0"),
        // Calidad de código (PRD-AF-09): SwiftLint como build-tool plugin, con la
        // configuración curada en `.swiftlint.yml`. Complementa a ArchitectureLint:
        // archlint valida DÓNDE está el código (capas), SwiftLint CÓMO está escrito.
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.65.0")
    ],
    targets: [
        .target(
            name: "AppStarterKit",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking")
            ],
            path: "Sources/AppStarterKit",
            swiftSettings: swiftSettings,
            plugins: [
                // ArchitectureLint activo en el propio paquete (PRD-APP-01, criterio de
                // aceptación 3): cada `swift build`/build de Xcode corre `archlint` sobre
                // `Sources/AppStarterKit` antes de compilar.
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "AppStarterKitTests",
            dependencies: [
                "AppStarterKit",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "CoreNetworkingTestSupport", package: "CoreNetworking")
            ],
            path: "Tests/AppStarterKitTests",
            swiftSettings: swiftSettings
        )
    ]
)
