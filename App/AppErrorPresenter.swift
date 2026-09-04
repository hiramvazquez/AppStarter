import AppFoundation
import Foundation

/// The single place this app maps an error to `ScreenError` copy. Every `Logic` in
/// AppStarter translates `APIError`/SwiftData failures into its own `XxxError:
/// DomainError` (M1) before it ever reaches a `ViewModel` — this presenter only has to
/// reason about `any DomainError`, exactly like
/// `AppFoundation/Examples/LoginApp/Sources/LoginApp/AppErrorPresenter.swift`, which this
/// mirrors: `retry` is offered only when `isRetryable` says the operation is worth
/// repeating.
///
/// Lives in `App/` (the cáscara), not in `Domain`/`Networking`: it is pure composition —
/// installed once at startup (`AppStarterApp.init()`) — and no feature ever references it
/// directly.
///
/// Registered once at app startup:
/// ```swift
/// BaseViewModel.errorPresenter = AppErrorPresenter()
/// ```
struct AppErrorPresenter: ErrorPresenting {
    func screenError(for error: any Error, fallbackTitle: String, retry: Action?) -> ScreenError {
        guard let domainError = error as? any DomainError else {
            return DefaultErrorPresenter().screenError(for: error, fallbackTitle: fallbackTitle, retry: retry)
        }

        let base = domainError.screenError
        return ScreenError(
            title: base.title,
            message: base.message,
            retry: domainError.isRetryable ? (retry ?? base.retry) : nil
        )
    }
}
