import Domain
import Foundation
import os

/// The `AnalyticsTracking` (`Domain`) this app runs with: a console adapter — prints every
/// event via `os.Logger` — that ALSO keeps the last `capacity` events in memory, so
/// `Settings` (tramo B, PRD-APP-02) can show a "recent activity" list without a real
/// Analytics SDK. `.archlint.yml` restricts this target to `[Foundation, Domain,
/// Analytics*]`: it is the ONLY module allowed to import an Analytics SDK — swap this
/// type's body for a real one (its own dependency in `Package.swift`, its own `import
/// Analytics...`) without touching any feature.
///
/// `actor`, not a lock-guarded class: `track(_:)` is already `async` (the protocol
/// requirement), and the recent-events buffer is genuinely shared mutable state read from
/// a different call site (`Settings`) than it's written from (every feature that tracks).
public actor ConsoleAnalyticsAdapter: AnalyticsTracking {
    private static let log = Logger(subsystem: "com.appstarter.analytics", category: "console")

    private let capacity: Int
    private var recent: [AnalyticsEvent] = []

    public init(capacity: Int = 20) {
        self.capacity = capacity
    }

    public func isConfigured() -> Bool {
        true
    }

    public func track(_ event: AnalyticsEvent) async {
        // Default (`.private`) privacy on purpose (`.swiftlint.yml`'s
        // `os_log_public_interpolation`, PRD-CN-04's own `LoggingInterceptor` follows the
        // same rule for URLs/bodies): an event's name/parameters could carry user-entered
        // text (e.g. a product title) — visible in Xcode's live console while debugging,
        // redacted in a release build's sysdiagnose.
        Self.log.debug("event: \(event.name) \(event.parameters)")
        recent.append(event)
        if recent.count > capacity {
            recent.removeFirst(recent.count - capacity)
        }
    }

    /// The last `capacity` tracked events, most recent last. `Settings` (tramo B) reads
    /// this to show "actividad reciente".
    public func recentEvents() async -> [AnalyticsEvent] {
        recent
    }
}
