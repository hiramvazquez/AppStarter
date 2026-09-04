import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `ProfileViewModel`. Native chrome — never references
/// `ProfileLogic`/`ProfileService`/`APIService` directly.
public struct ProfileView: View {
    @State private var viewModel: ProfileViewModel

    public init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            List {
                if let profile = viewModel.profile {
                    Section {
                        HStack(spacing: 16) {
                            AsyncImage(url: profile.imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text("\(profile.firstName) \(profile.lastName)")
                                    .font(.headline)
                                Text(profile.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("profile.content")
                    }

                    if viewModel.refreshCount > 0 {
                        Section("Renovación de sesión") {
                            Text("El token se renovó automáticamente \(viewModel.refreshCount) vez(es).")
                            if let date = viewModel.lastRefreshDate {
                                Text("Última renovación: \(date.formatted(date: .abbreviated, time: .standard))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("profile.refreshInfo")
                    }
                }

                Section("Escaparate de CoreNetworking") {
                    Button("Diagnostics") { send(.openDiagnostics) }
                        .accessibilityIdentifier("profile.diagnostics")
                    Button("Subir foto") { send(.openUploads) }
                        .accessibilityIdentifier("profile.uploads")
                }

                Section {
                    Button("Cerrar sesión", role: .destructive) {
                        send(.logoutRequested)
                    }
                    .accessibilityIdentifier("profile.logout")
                }
            }
            .onAppear { send(.load) }
        }
        .navigationTitle("Perfil")
    }
}
#endif

// MARK: - Preview: a stub, no real network pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
import Domain
import Networking

private final class ProfilePreviewLogic: ProfileLogicProtocol {
    func loadProfile() async throws -> UserProfile {
        UserProfile(
            id: 1,
            username: "emilys",
            email: "emily.johnson@x.dummyjson.com",
            firstName: "Emily",
            lastName: "Johnson",
            imageURL: nil
        )
    }
    func logout() async {}
}

#Preview {
    NavigationStack {
        ProfileView(
            viewModel: ProfileViewModel(
                logic: ProfilePreviewLogic(),
                sessionState: AppSessionState(router: Coordinator(root: .profile)),
                refreshLog: RefreshActivityLog(),
                router: Coordinator<AppRoute>(root: .profile)
            )
        )
    }
}
#endif
