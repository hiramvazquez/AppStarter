import AppFoundation
import Domain
import Foundation
import Networking
import Observation
import PlatformTestSupport
import Testing

@testable import ProfileFeature

@Suite("ProfileViewModel")
@MainActor
struct ProfileViewModelTests {
    @Test("handle(.load) calls logic.loadProfile and reaches .content")
    func loadReachesContent() async {
        let mock = ProfileLogicMock()
        let sessionState = AppSessionState(router: Coordinator(root: .profile))
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: sessionState,
            refreshLog: RefreshActivityLog(),
            router: Coordinator(root: .profile)
        )

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.phase == .content)
        #expect(viewModel.profile == mock.profileToReturn)
    }

    @Test("handle(.logout) calls logic.logout and routes back to .login")
    func logoutRoutesToLogin() async {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let sessionState = AppSessionState(router: router)
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: sessionState,
            refreshLog: RefreshActivityLog(),
            router: Coordinator(root: .profile)
        )

        viewModel.handle(.logout)
        await viewModel.inFlightActivity?.value

        #expect(await mock.logoutCalls.wasCalled)
        #expect(router.mainStack.root == .login)
    }

    @Test("handle(.logoutRequested) shows a destructive confirmation alert, without logging out yet")
    func logoutRequestedShowsAlert() async {
        let mock = ProfileLogicMock()
        let sessionState = AppSessionState(router: Coordinator(root: .profile))
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: sessionState,
            refreshLog: RefreshActivityLog(),
            router: Coordinator(root: .profile)
        )

        viewModel.handle(.logoutRequested)

        #expect(viewModel.alert != nil)
        #expect(await mock.logoutCalls.isEmpty)
    }

    @Test("Confirming the alert's primary button calls logic.logout and routes back to .login")
    func confirmingLogoutAlertLogsOut() async {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let sessionState = AppSessionState(router: router)
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: sessionState,
            refreshLog: RefreshActivityLog(),
            router: Coordinator(root: .profile)
        )

        viewModel.handle(.logoutRequested)
        viewModel.alert?.primaryButton.action()
        await viewModel.inFlightActivity?.value

        #expect(await mock.logoutCalls.wasCalled)
        #expect(router.mainStack.root == .login)
    }

    @Test("Logging out discards the session-scoped Container(parent:) child")
    func logoutDiscardsSessionContainer() async {
        let mock = ProfileLogicMock()
        let sessionState = AppSessionState(router: Coordinator(root: .profile), parentContainer: Container())
        sessionState.startSession()
        let containerBeforeLogout = sessionState.sessionContainer
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: sessionState,
            refreshLog: RefreshActivityLog(),
            router: Coordinator(root: .profile)
        )

        viewModel.handle(.logout)
        await viewModel.inFlightActivity?.value

        #expect(sessionState.sessionContainer !== containerBeforeLogout)
    }

    @Test("handle(.openDiagnostics)/(.openUploads) push their routes")
    func openDiagnosticsAndUploadsPushRoutes() {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: AppSessionState(router: Coordinator(root: .profile)),
            refreshLog: RefreshActivityLog(),
            router: router
        )

        viewModel.handle(.openDiagnostics)
        #expect(router.mainStack.path == [.diagnostics])

        viewModel.handle(.openUploads)
        #expect(router.mainStack.path == [.diagnostics, .uploads])
    }

    @Test("refreshCount/lastRefreshDate mirror RefreshActivityLog")
    func refreshInfoMirrorsLog() {
        let log = RefreshActivityLog()
        log.recordRefresh(now: Date(timeIntervalSince1970: 100))
        let viewModel = ProfileViewModel(
            logic: ProfileLogicMock(),
            sessionState: AppSessionState(router: Coordinator(root: .profile)),
            refreshLog: log,
            router: Coordinator(root: .profile)
        )

        #expect(viewModel.refreshCount == 1)
        #expect(viewModel.lastRefreshDate == Date(timeIntervalSince1970: 100))
    }

    @Test("Changing profile notifies Observation — ProfileViewModel's own @Observable (docs/INFORME-MULTI.md §11)")
    func changingProfileNotifiesObservation() async {
        let mock = ProfileLogicMock()
        let viewModel = ProfileViewModel(
            logic: mock,
            sessionState: AppSessionState(router: Coordinator(root: .profile)),
            refreshLog: RefreshActivityLog(),
            router: Coordinator(root: .profile)
        )
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.profile
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(flag.fired)
    }
}
