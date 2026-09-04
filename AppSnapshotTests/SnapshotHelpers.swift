import AppFoundation
import SwiftUI
import UIKit

@testable import AppStarter

/// PRD-APP-02, Fase 3: shared plumbing for `DiagnosticsSnapshotTests`/
/// `UploadsSnapshotTests`/`GallerySnapshotTests` — the 4×3×2 matrix (loading/empty/error/
/// content × Diagnostics/Uploads/Gallery × kit/brand theme).
enum SnapshotTheme {
    case kit
    case brand
}

/// Installs the SAME four `Brand…Style`s `RootView` installs when `Settings`' "tema de
/// marca" toggle is on (`App/RootView.swift`) — `@testable import AppStarter` is what
/// makes these `internal` types reachable from this separate test target, exactly like
/// `AppTests`' own `@testable import AppStarter` already does for `AppDeepLink`/
/// `Coordinator` (`AppTests/DeepLinkTests.swift`).
extension View {
    @ViewBuilder
    func snapshotTheme(_ theme: SnapshotTheme) -> some View {
        switch theme {
        case .kit:
            self
        case .brand:
            self
                .loadingViewStyle(BrandLoadingStyle())
                .errorViewStyle(BrandErrorStyle())
                .emptyViewStyle(BrandEmptyStyle())
                .bannerViewStyle(BrandBannerStyle())
        }
    }
}

/// Full device frame, read from the simulator actually running this test — never
/// hardcoded (a fixed point size would silently stop matching whatever the scheme's
/// destination simulator is, `iPhone 17 Pro` today).
@MainActor
var snapshotDeviceSize: CGSize {
    UIScreen.main.bounds.size
}

/// Polls `condition` until it's true or `timeout` elapses — used instead of awaiting a
/// `Task` handle for the ViewModel work this suite drives through unstructured `Task`s
/// (`DiagnosticsViewModel.run`, `UploadsViewModel.upload`) that aren't tracked in
/// `inFlightLoad`/`inFlightActivity`. Every Logic this suite injects is a synchronous,
/// in-memory stub (no network) — completion is a handful of run-loop turns away, so a
/// short timeout is a genuine bug signal, not flakiness.
@MainActor
func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: @autoclosure @escaping () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
