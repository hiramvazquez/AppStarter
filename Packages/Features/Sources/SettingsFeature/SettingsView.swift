import AppFoundation
import Domain

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `SettingsViewModel`. Native chrome — never references
/// `SettingsLogic`/`SettingsStore`/`APIService` directly. Entry: `Profile` (`send(
/// .openSettings)`, PRD-APP-02 tramo B item 2).
public struct SettingsView: View {
    // The composition root builds the view model; the view RETAINS it. `@State` keeps the
    // same instance alive when SwiftUI re-runs this initializer (a navigation destination
    // builder during a push does) — with `let`, the instance that received `.load` could
    // be replaced by one that never does, leaving the screen empty with no error.
    @State private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            List {
                Section("Apariencia") {
                    Toggle(
                        "Tema de marca",
                        isOn: Binding(get: { viewModel.settings.themeIsBrand }, set: { send(.toggleTheme($0)) })
                    )
                    .accessibilityIdentifier("settings.themeToggle")
                }

                Section {
                    Toggle(
                        "Pinning estricto",
                        isOn: Binding(
                            get: { viewModel.settings.pinningStrict },
                            set: { send(.togglePinningStrict($0)) }
                        )
                    )
                    .accessibilityIdentifier("settings.pinningToggle")

                    if viewModel.settings.pinningStrict {
                        Toggle(
                            "Pin falso (demo .untrustedServer)",
                            isOn: Binding(get: { viewModel.settings.useFakePin }, set: { send(.toggleFakePin($0)) })
                        )
                        .accessibilityIdentifier("settings.fakePinToggle")
                    }

                    Text(viewModel.activePinningSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.pinningSummary")
                } header: {
                    Text("Seguridad de red")
                } footer: {
                    Text("Un cambio en el pinning se aplica al reiniciar la app — ver README.md.")
                }

                Section("Entorno") {
                    LabeledContent("Build", value: AppEnvironment.isDebug ? "Debug" : "Release")
                    LabeledContent("Versión", value: AppEnvironment.fullVersion)
                }
                .accessibilityIdentifier("settings.environment")

                Section("Red") {
                    LabeledContent("Base URL", value: viewModel.activeBaseURL)
                }
                .accessibilityIdentifier("settings.networking")

                Section("Actividad reciente") {
                    if viewModel.recentEvents.isEmpty {
                        Text("Sin eventos todavía.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.recentEvents.enumerated()), id: \.offset) { _, event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name).font(.body)
                                if !event.parameters.isEmpty {
                                    Text(event.parameters.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("settings.recentEvents")
            }
            .task { send(.load) }
        }
        .navigationTitle("Ajustes")
    }
}
#endif

// MARK: - Preview: a stub, never used outside DEBUG (same pattern as
// `AppFoundation/Examples/LoginApp/Sources/LoginApp/Features/Login/LoginView.swift`'s
// `LoginPreview` — this scaffolding is exempt from the layering rules, `ArchLint.R4`
// included: see `archlint`'s `#if DEBUG`/`#Preview` exemption).

#if canImport(SwiftUI) && DEBUG
import Networking

/// Stub de `SettingsLogicProtocol` solo para el `#Preview` de abajo. La spy con
/// contadores para los tests (M9) es `SettingsLogicMock`, en el target de tests.
private final class SettingsPreviewLogic: SettingsLogicProtocol {
    func load() async throws -> SettingsScreenState {
        SettingsScreenState(
            settings: AppSettings(),
            activeBaseURL: "https://dummyjson.com",
            activePinningSummary: "Desactivado — validación TLS del sistema",
            recentEvents: []
        )
    }
    func save(_ settings: AppSettings) async throws -> SettingsScreenState {
        try await load()
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(logic: SettingsPreviewLogic(), themeSettings: ThemeSettings(isBrand: false))
        )
    }
}
#endif
