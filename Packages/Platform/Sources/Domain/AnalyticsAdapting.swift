import Foundation

/// Contract for the Analytics integration, implemented by the `AnalyticsAdapters` target.
/// Features depend on THIS protocol, never on the Analytics SDK directly — `AnalyticsAdapters`
/// is the only module allowed to import it (`.archlint.yml`, R13:
/// `allowedImports: [Foundation, Domain, Analytics*]`).
public protocol AnalyticsAdapting: Sendable {
    func isConfigured() -> Bool
}
