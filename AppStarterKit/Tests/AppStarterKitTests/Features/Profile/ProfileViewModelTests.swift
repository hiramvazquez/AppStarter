import AppFoundation
import Foundation
import Testing

@testable import AppStarterKit

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

    @Test("refreshCount/lastRefreshDate mirror RefreshActivityLog")
    func refreshInfoMirrorsLog() {
        let log = RefreshActivityLog()
        log.recordRefresh(now: Date(timeIntervalSince1970: 100))
        let viewModel = ProfileViewModel(logic: ProfileLogicMock(), router: Coordinator(root: .profile), refreshLog: log)

        #expect(viewModel.refreshCount == 1)
        #expect(viewModel.lastRefreshDate == Date(timeIntervalSince1970: 100))
    }
}
