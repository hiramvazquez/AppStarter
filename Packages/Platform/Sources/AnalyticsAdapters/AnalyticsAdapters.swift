import Domain
import Foundation

/// Stub — wire the real Analytics SDK here (its own dependency in `Package.swift`, its own
/// `import Analytics...`). `.archlint.yml` restricts this target to `[Foundation, Domain,
/// Analytics*]`: it is the ONLY module allowed to import the Analytics SDK (R13).
public struct AnalyticsAdapterStub: AnalyticsAdapting {
    public init() {}

    public func isConfigured() -> Bool {
        false
    }
}
