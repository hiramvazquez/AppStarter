import AppFoundation
import Domain
import Foundation
import Networking
import Observation
import PlatformTestSupport
import Testing

@testable import LoginFeature

/// `LoginViewModel` tested only against `LoginLogicMock` — no `AuthService`/
/// `SessionStore` real, no network involved.
@Suite("LoginViewModel")
@MainActor
struct LoginViewModelTests {
    @Test("handle(.login) calls logic.login and routes to .products on success")
    func loginRoutesToProducts() async {
        let mock = LoginLogicMock()
        let router = Coordinator<AppRoute>(root: .login)
        let sessionState = AppSessionState(router: router)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: sessionState)

        viewModel.handle(.updateUsername("emilys"))
        viewModel.handle(.updatePassword("emilyspass"))
        viewModel.handle(.login)
        await viewModel.inFlightLoad?.value

        #expect(await mock.logins.calls == ["emilys"])
        #expect(viewModel.phase == .content)
        #expect(router.mainStack.root == .products)
    }

    @Test("A failing logic.login lands on .error and does not navigate")
    func loginFailureSurfacesError() async {
        let mock = LoginLogicMock()
        mock.errorToThrow = LoginError.invalidCredentials
        let router = Coordinator<AppRoute>(root: .login)
        let sessionState = AppSessionState(router: router)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: sessionState)

        viewModel.handle(.updateUsername("emilys"))
        viewModel.handle(.updatePassword("wrong"))
        viewModel.handle(.login)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.hasError)
        #expect(router.mainStack.root == .login)
    }

    @Test("appear() shows a banner once when the session expired, then clears the flag")
    func appearShowsExpiryBannerOnce() async {
        let mock = LoginLogicMock()
        let router = Coordinator<AppRoute>(root: .login)
        let sessionState = AppSessionState(router: router)
        await sessionState.sessionDidExpire()
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: sessionState)

        viewModel.handle(.appear)
        #expect(viewModel.banner != nil)

        viewModel.dismissBanner()
        viewModel.handle(.appear)
        #expect(viewModel.banner == nil)
    }

    @Test("Changing username notifies Observation — LoginViewModel declares its own @Observable (§11)")
    func changingUsernameNotifiesObservation() {
        let mock = LoginLogicMock()
        let router = Coordinator<AppRoute>(root: .login)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: AppSessionState(router: router))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.username
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.updateUsername("emilys"))

        #expect(flag.fired)
    }
}
