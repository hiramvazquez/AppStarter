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
        .library(name: "ProductsFeature", targets: ["ProductsFeature"]),
        .library(name: "ProductDetailFeature", targets: ["ProductDetailFeature"]),
        .library(name: "FavoritesFeature", targets: ["FavoritesFeature"]),
        .library(name: "ProfileFeature", targets: ["ProfileFeature"]),
        .library(name: "SearchFeature", targets: ["SearchFeature"]),
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
        .target(
            name: "ProductsFeature",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking"),
                .product(name: "Domain", package: "Platform"),
                .product(name: "Networking", package: "Platform"),
            ],
            path: "Sources/ProductsFeature",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
            ]
        ),
        .testTarget(
            name: "ProductsFeatureTests",
            dependencies: [
                "ProductsFeature",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "CoreNetworkingTestSupport", package: "CoreNetworking"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/ProductsFeatureTests",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "ProductDetailFeature",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking"),
                .product(name: "Domain", package: "Platform"),
                .product(name: "Networking", package: "Platform"),
            ],
            path: "Sources/ProductDetailFeature",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
            ]
        ),
        .testTarget(
            name: "ProductDetailFeatureTests",
            dependencies: [
                "ProductDetailFeature",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "CoreNetworkingTestSupport", package: "CoreNetworking"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/ProductDetailFeatureTests",
            swiftSettings: swiftSettings
        ),
        // FavoritesFeature no depende de CoreNetworking/Networking (SwiftData, --local):
        // generate-feature en modo multi solo añade CoreNetworking con --api.
        .target(
            name: "FavoritesFeature",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "Domain", package: "Platform"),
            ],
            path: "Sources/FavoritesFeature",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
            ]
        ),
        .testTarget(
            name: "FavoritesFeatureTests",
            dependencies: [
                "FavoritesFeature",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/FavoritesFeatureTests",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "ProfileFeature",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking"),
                .product(name: "Domain", package: "Platform"),
                .product(name: "Networking", package: "Platform"),
            ],
            path: "Sources/ProfileFeature",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
            ]
        ),
        .testTarget(
            name: "ProfileFeatureTests",
            dependencies: [
                "ProfileFeature",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "CoreNetworkingTestSupport", package: "CoreNetworking"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/ProfileFeatureTests",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SearchFeature",
            dependencies: [
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking"),
                .product(name: "Domain", package: "Platform"),
                .product(name: "Networking", package: "Platform"),
            ],
            path: "Sources/SearchFeature",
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "ArchitectureLint", package: "AppFoundation"),
            ]
        ),
        .testTarget(
            name: "SearchFeatureTests",
            dependencies: [
                "SearchFeature",
                .product(name: "AppFoundationTestSupport", package: "AppFoundation"),
                .product(name: "CoreNetworkingTestSupport", package: "CoreNetworking"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/SearchFeatureTests",
            swiftSettings: swiftSettings
        ),
        // archinit:features-end
        // No generado por archinit --multi/generate-feature — añadido a mano (PRD-APP-02,
        // Fase 1): la prueba de integración real contra DummyJSON necesita AuthService
        // (Networking), ProductsService (ProductsFeature) y ProfileService (ProfileFeature)
        // a la vez, algo que ningún *FeatureTests individual puede expresar sin importar
        // otro feature (R13 lo prohibiría en producción; en Tests/** la regla no aplica,
        // pero un target de integración aparte, fuera de los markers, es más claro que
        // forzar esa dependencia dentro de LoginFeatureTests).
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "LoginFeature",
                "ProductsFeature",
                "ProfileFeature",
                .product(name: "AppFoundation", package: "AppFoundation"),
                .product(name: "CoreNetworking", package: "CoreNetworking"),
                .product(name: "Domain", package: "Platform"),
                .product(name: "Networking", package: "Platform"),
                .product(name: "PlatformTestSupport", package: "Platform"),
            ],
            path: "Tests/IntegrationTests",
            swiftSettings: swiftSettings
        ),
    ]
)
