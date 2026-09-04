import AppFoundation
import Foundation
import Observation

/// Orchestrates the Diagnostics lab: one independent run per experiment (never imports
/// CoreNetworking, never references `DiagnosticsService` directly — only `logic`).
///
/// Every experiment BUT the slow/cancelable one runs on its OWN unstructured `Task`,
/// tracked in `experimentTasks` — `BaseViewModel`'s `inFlightLoad`/`inFlightActivity` are
/// single-slot (starting a new one cancels the previous), which does not fit a screen
/// where several independent rows can be running at once. The slow request is the
/// exception on purpose: it is what `--api --no-service`'s PRD row asks to demonstrate
/// `performLoad`'s `inFlightLoad` + `CancellationRecognizing` with, so it goes through
/// `performLoad` like any other feature's primary load — `.overlay` style (never
/// `.fullScreen`: that would hide the row's own "Cancelar" button along with the rest of
/// the content) while it's in flight, cancelable from that button.
/// `@Observable` (in addition to `AppFoundation.BaseViewModel`'s own): a real, reproduced
/// bug, not defensive boilerplate. `@Observable`'s macro only instruments STORED
/// PROPERTIES DECLARED IN THE CLASS IT'S ATTACHED TO — it does not propagate through
/// subclassing. Every OTHER feature's ViewModel always mutates its own added properties
/// (`items`, etc.) INSIDE `performLoad`/`performActivity`, which also flips a genuinely
/// `BaseViewModel`-tracked property (`phase`/`activity`) in the same call — SwiftUI
/// re-renders because of THAT tracked change, then simply reads the (untracked, but by
/// then already-current) subclass property fresh. Diagnostics' non-slow experiments run
/// on their OWN `Task`s and mutate ONLY `results`/`runningExperiments` — no
/// `BaseViewModel` property EVER changes for them — so without this second `@Observable`,
/// NO experiment's result ever appeared on screen, confirmed by adding an
/// `os.Logger`-based render counter: `DiagnosticsView.body` ran exactly twice at launch
/// (`.idle` → `.content`) and never again, no matter how many experiments finished.
/// Reproduced and fixed with `DiagnosticsUITests` against the Simulator; see
/// `docs/INFORME-MULTI.md` for the full repro and `UploadsViewModel`'s doc comment for
/// the same fix applied there (a cosmetic instance of the identical bug: its `progress`
/// bar would jump straight to 100% instead of animating).
@MainActor
@Observable
public final class DiagnosticsViewModel: LogicViewModel<any DiagnosticsLogicProtocol>, ActionHandling {
    public private(set) var results: [DiagnosticsExperiment: DiagnosticsResult] = [:]
    public private(set) var runningExperiments: Set<DiagnosticsExperiment> = []
    public private(set) var logLines: [String] = []

    @ObservationIgnored
    private var experimentTasks: [DiagnosticsExperiment: Task<Void, Never>] = [:]

    public enum Action: Sendable {
        case appear
        case run(DiagnosticsExperiment)
        case cancelSlow
    }

    public func handle(_ action: Action) {
        switch action {
        case .appear: appear()
        case .run(let experiment): run(experiment)
        case .cancelSlow: inFlightLoad?.cancel()
        }
    }

    deinit {
        for (_, task) in experimentTasks { task.cancel() }
    }

    public func result(for experiment: DiagnosticsExperiment) -> DiagnosticsResult? {
        results[experiment]
    }

    public func isRunning(_ experiment: DiagnosticsExperiment) -> Bool {
        runningExperiments.contains(experiment)
    }

    private func appear() {
        guard isIdle else { return }
        setContent()
    }

    private func run(_ experiment: DiagnosticsExperiment) {
        guard !runningExperiments.contains(experiment) else { return }

        if experiment == .slowCancelable {
            runningExperiments.insert(experiment)
            // `performLoad` is used for its `inFlightLoad`/`CancellationRecognizing`
            // machinery (PRD-APP-02), not its VISUAL overlay: both `.fullScreen` (hides
            // content entirely, `ScreenPresentationLogic.hidesContent`) and `.overlay`
            // (a screen-wide, tap-blocking scrim) cover this row's own "Cancelar" button
            // for the exact duration it needs to stay tappable. `setContent()` as the
            // work closure's first line reverts the transient `.loading` phase almost
            // immediately — this row's `isRunning`-driven UI is the real "in progress"
            // indicator.
            performLoad(style: .overlay, successTransition: .preserveCurrentPhase) { vm in
                vm.setContent()
                let result = await vm.logic.run(experiment)
                vm.runningExperiments.remove(experiment)
                vm.results[experiment] = result
                await vm.refreshLog()
            }
            return
        }

        runningExperiments.insert(experiment)
        experimentTasks[experiment] = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.logic.run(experiment)
            self.runningExperiments.remove(experiment)
            self.results[experiment] = result
            self.experimentTasks[experiment] = nil
            await self.refreshLog()
        }
    }

    private func refreshLog() async {
        logLines = await logic.capturedLogLines()
    }
}
