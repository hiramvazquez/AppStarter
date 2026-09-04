import AppFoundation
import Domain
import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `LoginViewModel`. Native chrome (`navigationTitle`) — only
/// `ProductDetailFeature` opts into `chrome: .custom` in this app. Never references
/// `LoginLogic`/`AuthService`/`APIService` — only `viewModel` (reads) and `send` (actions).
public struct LoginView: View {
    @State private var viewModel: LoginViewModel

    public init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            Form {
                Section {
                    Text("Usuario de prueba: emilys / emilyspass")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Credenciales") {
                    TextField(
                        "Usuario",
                        text: Binding(get: { viewModel.username }, set: { send(.updateUsername($0)) })
                    )
                    .textContentType(.username)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .accessibilityIdentifier("login.username")

                    SecureField(
                        "Contraseña",
                        text: Binding(get: { viewModel.password }, set: { send(.updatePassword($0)) })
                    )
                    // `.textContentType(.password)` is what makes iOS offer to save the
                    // credential after submit — genuinely useful for a real signed-in
                    // user, but the resulting "¿Guardar contraseña?" system sheet is an
                    // unpredictably-timed interruption an XCUITest can't reliably wait out
                    // (confirmed empirically: it made every screen after login flaky,
                    // `docs/INFORME-INTEGRACION.md`). `XCTestConfigurationFilePath` is set
                    // by Xcode's test runner in-process whenever XCUITest is driving this
                    // app, regardless of scheme or launch arguments — skip the content
                    // type only then.
                    .textContentType(Self.isRunningUITests ? nil : .password)
                    .accessibilityIdentifier("login.password")
                }

                Button("Iniciar sesión") {
                    send(.login)
                }
                .accessibilityIdentifier("login.submit")
            }
            .onAppear { send(.appear) }
        }
        .navigationTitle("AppStarter")
    }

    private static var isRunningUITests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
#endif

// MARK: - Preview: a stub, no real network pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
import AppFoundation
import Networking

private final class LoginPreviewLogic: LoginLogicProtocol {
    func login(username: String, password: String) async throws {}
}

#Preview {
    NavigationStack {
        LoginView(
            viewModel: LoginViewModel(
                logic: LoginPreviewLogic(),
                router: Coordinator(root: .login),
                sessionState: AppSessionState(router: Coordinator<AppRoute>(root: .login))
            )
        )
    }
}
#endif
