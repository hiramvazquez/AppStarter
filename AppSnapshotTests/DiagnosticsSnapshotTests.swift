import DiagnosticsFeature
import SnapshotTesting
import SwiftUI
import XCTest

/// PRD-APP-02, Fase 3: `DiagnosticsView` in loading/empty/error/content, under the kit's
/// own styles and the brand's (`App/Theme/`). `DiagnosticsViewModel.appear()` always goes
/// straight to `.content` (it never fails) — loading/empty/error are injected directly
/// through `BaseViewModel`'s own public `setLoading`/`setEmpty`/`setError` (PRD-APP-02:
/// "los estados se inyectan por ViewModel/Logic mock, sin red"), the same states the
/// `Diagnostics` row of `App/Theme/BrandErrorStyle.swift`'s doc comment refers to.
@MainActor
final class DiagnosticsSnapshotTests: XCTestCase {
    private struct StubLogic: DiagnosticsLogicProtocol {
        func run(_ experiment: DiagnosticsExperiment) async -> DiagnosticsResult {
            DiagnosticsResult(
                experiment: experiment,
                outcome: DiagnosticsOutcome(
                    succeeded: false,
                    category: "notFound",
                    code: "httpStatus",
                    requestSummary: "GET /products/999999",
                    responseSummary: "404 — 32 bytes"
                )
            )
        }
        func capturedLogLines() async -> [String] {
            ["→ intento 1: GET /diagnostics/retry-demo", "← intento 1: 503", "← intento 2: 200"]
        }
    }

    private func makeViewModel() -> DiagnosticsViewModel {
        DiagnosticsViewModel(logic: StubLogic())
    }

    private func assertDiagnostics(
        _ viewModel: DiagnosticsViewModel,
        theme: SnapshotTheme,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let view = NavigationStack { DiagnosticsView(viewModel: viewModel) }
            .snapshotTheme(theme)
            .frame(width: snapshotDeviceSize.width, height: snapshotDeviceSize.height)
        assertSnapshot(
            of: view,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                layout: .fixed(
                    width: snapshotDeviceSize.width,
                    height: snapshotDeviceSize.height
                )
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    func testLoadingKit() {
        let vm = makeViewModel()
        vm.setLoading(.fullScreen)
        assertDiagnostics(vm, theme: .kit, named: "kit")
    }

    func testLoadingBrand() {
        let vm = makeViewModel()
        vm.setLoading(.fullScreen)
        assertDiagnostics(vm, theme: .brand, named: "brand")
    }

    func testEmptyKit() {
        let vm = makeViewModel()
        vm.setEmpty()
        assertDiagnostics(vm, theme: .kit, named: "kit")
    }

    func testEmptyBrand() {
        let vm = makeViewModel()
        vm.setEmpty()
        assertDiagnostics(vm, theme: .brand, named: "brand")
    }

    func testErrorKit() {
        let vm = makeViewModel()
        vm.setError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        assertDiagnostics(vm, theme: .kit, named: "kit")
    }

    func testErrorBrand() {
        let vm = makeViewModel()
        vm.setError(title: "Algo salió mal", message: "Inténtalo de nuevo.")
        assertDiagnostics(vm, theme: .brand, named: "brand")
    }

    func testContentKit() async {
        let vm = makeViewModel()
        vm.handle(.appear)
        vm.handle(.run(.notFound404))
        await waitUntil(vm.result(for: .notFound404) != nil)
        assertDiagnostics(vm, theme: .kit, named: "kit")
    }

    func testContentBrand() async {
        let vm = makeViewModel()
        vm.handle(.appear)
        vm.handle(.run(.notFound404))
        await waitUntil(vm.result(for: .notFound404) != nil)
        assertDiagnostics(vm, theme: .brand, named: "brand")
    }
}
