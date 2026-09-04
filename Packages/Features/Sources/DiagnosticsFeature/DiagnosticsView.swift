import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `DiagnosticsViewModel` — the CoreNetworking showcase
/// (PRD-APP-02): a list of experiments, each a button that fires a real (or, offline,
/// fixture) DummyJSON call and renders its result inline: `APIError` category/code,
/// `RequestSummary`/`ResponseSummary` (as text — never the type itself, M2), the
/// `DomainError` the Logic mapped it to, and `isRetryable`. Never references
/// `DiagnosticsLogic`/`DiagnosticsService`/`APIService` directly.
public struct DiagnosticsView: View {
    @State private var viewModel: DiagnosticsViewModel

    public init(viewModel: DiagnosticsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            // Row data, read eagerly here (matches `ProductsView` passing
            // `viewModel.items` as `List`'s data source) rather than lazily inside
            // `ForEach`'s row closure — good practice for a `ForEach` this size
            // regardless, though the real fix for this screen's state not updating was
            // `@Observable` on `DiagnosticsViewModel` itself (see its doc comment and
            // `docs/INFORME-MULTI.md`).
            let rows = DiagnosticsExperiment.allCases.map { experiment in
                ExperimentRowData(
                    experiment: experiment,
                    result: viewModel.result(for: experiment),
                    isRunning: viewModel.isRunning(experiment)
                )
            }
            let logLines = viewModel.logLines

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Experimentos")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    ForEach(rows) { row in
                        ExperimentRow(
                            row: row,
                            onRun: { send(.run(row.experiment)) },
                            onCancel: { send(.cancelSlow) }
                        )
                        .padding(.horizontal)
                        Divider()
                    }

                    Text("Cada botón lanza una petición real contra DummyJSON (o su fixture offline).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    if !logLines.isEmpty {
                        Text("Log capturado (RequestCounterInterceptor)")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .accessibilityIdentifier("diagnostics.log")
                    }
                }
            }
            .accessibilityIdentifier("diagnostics.list")
            .task { send(.appear) }
        }
        .navigationTitle("Diagnostics")
    }
}

/// Plain value snapshot of one row's state — computed EAGERLY in `DiagnosticsView.body`
/// (see the comment there) and handed to `ExperimentRow` as captured values.
private struct ExperimentRowData: Identifiable {
    let experiment: DiagnosticsExperiment
    let result: DiagnosticsResult?
    let isRunning: Bool

    var id: DiagnosticsExperiment { experiment }
}

private struct ExperimentRow: View {
    let row: ExperimentRowData
    let onRun: () -> Void
    let onCancel: () -> Void

    private var experiment: DiagnosticsExperiment { row.experiment }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(experiment.title).font(.body)
                    Text(experiment.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if row.isRunning {
                    if experiment == .slowCancelable {
                        Button("Cancelar", role: .destructive, action: onCancel)
                            .accessibilityIdentifier("diagnostics.cancel.\(experiment.id)")
                    } else {
                        ProgressView()
                    }
                } else {
                    Button("Run", action: onRun)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("diagnostics.run.\(experiment.id)")
                }
            }

            if let result = row.result {
                VStack(alignment: .leading, spacing: 2) {
                    resultLine("Categoría", result.succeeded ? "success" : result.category, id: "category")
                    resultLine("Código", result.code, id: "code")
                    resultLine("Request", result.requestSummary, id: "request")
                    resultLine("Response", result.responseSummary, id: "response")
                    if result.attempts > 1 {
                        resultLine("Intentos", "\(result.attempts)", id: "attempts")
                    }
                    if let domainError = result.domainError {
                        resultLine("DomainError", String(describing: domainError), id: "domainError")
                        resultLine("isRetryable", result.isRetryable ? "true" : "false", id: "retryable")
                    }
                    if result.wasCancelled {
                        Text("Cancelado — CancellationRecognizing lo reconoció, no es un error.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("diagnostics.result.\(experiment.id).cancelled")
                    }
                    if result.isRetryable {
                        Button("Reintentar", action: onRun)
                            .font(.caption)
                            .accessibilityIdentifier("diagnostics.retry.\(experiment.id)")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func resultLine(_ label: String, _ value: String, id: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospaced())
        }
        // `.combine`: without it, this `HStack` has no accessibility label of its own —
        // VoiceOver/XCUITest would see the two `Text` children as separate elements
        // instead of one row whose label carries both ("Categoría" + the value).
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("diagnostics.result.\(experiment.id).\(id)")
    }
}
#endif

// MARK: - Preview: a stub, never used outside DEBUG

#if canImport(SwiftUI) && DEBUG
private nonisolated final class DiagnosticsPreviewLogic: DiagnosticsLogicProtocol {
    func run(_ experiment: DiagnosticsExperiment) async -> DiagnosticsResult {
        DiagnosticsResult(
            experiment: experiment,
            outcome: DiagnosticsOutcome(
                succeeded: false,
                category: "notFound",
                code: "httpStatus",
                requestSummary: "GET /products/999999",
                responseSummary: "404 — 0 bytes"
            )
        )
    }
    func capturedLogLines() async -> [String] { ["→ intento 1: GET /diagnostics/retry-demo", "← intento 1: 503"] }
}

#Preview {
    NavigationStack {
        DiagnosticsView(viewModel: DiagnosticsViewModel(logic: DiagnosticsPreviewLogic()))
    }
}
#endif
