import Foundation

/// One tracked event: a name plus flat string parameters — deliberately simple (no SDK
/// vocabulary, e.g. no Firebase `Parameters` type) since `Domain` only imports Foundation.
public nonisolated struct AnalyticsEvent: Sendable, Equatable {
    public let name: String
    public let parameters: [String: String]

    public init(name: String, parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

/// Contract for the Analytics integration, implemented by the `AnalyticsAdapters` target
/// (console adapter, PRD-APP-02) and by `InMemoryAnalytics` (`PlatformTestSupport`) in
/// tests. Features depend on THIS protocol, never on the Analytics SDK directly —
/// `AnalyticsAdapters` is the only module allowed to import it (`.archlint.yml`, R13:
/// `allowedImports: [Foundation, Domain, Analytics*]`).
public protocol AnalyticsTracking: Sendable {
    /// `async`: the real adapter (`ConsoleAnalyticsAdapter`) is an `actor` — its recent-
    /// events buffer is genuinely isolated state, so every requirement on this protocol is
    /// `async` even where a given implementation doesn't need to suspend.
    func isConfigured() async -> Bool

    /// Records one event. The app's own coordinator calls this with `"screen_view"` on
    /// every navigation (`App/RootView.swift`); `Uploads` calls it with `"upload"` on a
    /// successful upload.
    func track(_ event: AnalyticsEvent) async

    /// The last N tracked events, most recent last — `Settings` (PRD-APP-02) shows these
    /// as "actividad reciente". Part of the protocol (not just `ConsoleAnalyticsAdapter`'s
    /// own API) so `SettingsFeature` can depend on `any AnalyticsTracking` like every
    /// other feature does — `SettingsFeature` cannot import `AnalyticsAdapters` directly
    /// (R13: `forbiddenImports: ["Analytics*"]` on every `*Feature`).
    func recentEvents() async -> [AnalyticsEvent]
}
