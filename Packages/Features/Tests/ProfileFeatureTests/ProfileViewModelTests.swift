import AppFoundation
import Domain
import Foundation
import Networking
import Testing

@testable import ProfileFeature

@Suite("ProfileViewModel")
@MainActor
struct ProfileViewModelTests {
    @Test("handle(.load) calls logic.loadProfile and reaches .content")
    func loadReachesContent() async {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let viewModel = ProfileViewModel(logic: mock, router: router, refreshLog: RefreshActivityLog())

        viewModel.handle(.load)
        await viewModel.inFlightLoad?.value

        #expect(viewModel.phase == .content)
        #expect(viewModel.profile == mock.profileToReturn)
    }

    @Test("handle(.logout) calls logic.logout and routes back to .login")
    func logoutRoutesToLogin() async {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let viewModel = ProfileViewModel(logic: mock, router: router, refreshLog: RefreshActivityLog())

        viewModel.handle(.logout)
        await viewModel.inFlightActivity?.value

        #expect(await mock.logoutCalls.wasCalled)
        #expect(router.mainStack.root == .login)
    }

    @Test("handle(.logoutRequested) shows a destructive confirmation alert, without logging out yet")
    func logoutRequestedShowsAlert() async {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let viewModel = ProfileViewModel(logic: mock, router: router, refreshLog: RefreshActivityLog())

        viewModel.handle(.logoutRequested)

        #expect(viewModel.alert != nil)
        #expect(await mock.logoutCalls.isEmpty)
    }

    @Test("Confirming the alert's primary button calls logic.logout and routes back to .login")
    func confirmingLogoutAlertLogsOut() async {
        let mock = ProfileLogicMock()
        let router = Coordinator<AppRoute>(root: .profile)
        let viewModel = ProfileViewModel(logic: mock, router: router, refreshLog: RefreshActivityLog())

        viewModel.handle(.logoutRequested)
        viewModel.alert?.primaryButton.action()
        await viewModel.inFlightActivity?.value

        #expect(await mock.logoutCalls.wasCalled)
        #expect(router.mainStack.root == .login)
    }

    @Test("refreshCount/lastRefreshDate mirror RefreshActivityLog")
    func refreshInfoMirrorsLog() {
        let log = RefreshActivityLog()
        log.recordRefresh(now: Date(timeIntervalSince1970: 100))
        let viewModel = ProfileViewModel(
            logic: ProfileLogicMock(),
            router: Coordinator(root: .profile),
            refreshLog: log
        )

        #expect(viewModel.refreshCount == 1)
        #expect(viewModel.lastRefreshDate == Date(timeIntervalSince1970: 100))
    }
}
