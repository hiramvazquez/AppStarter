import AppFoundationTestSupport
import Domain
import Foundation

/// Spy that substitutes `AnalyticsTracking` in tests — shared the same way as
/// `SessionStoreSpy`/`ProductsServiceMock`: more than one `*FeatureTests` target
/// (`UploadsFeatureTests`, and any future feature that tracks events) needs it.
public actor InMemoryAnalytics: AnalyticsTracking {
    public let trackedEvents = SpyRecorder<AnalyticsEvent>()
    public var isConfiguredToReturn = true

    public init(isConfiguredToReturn: Bool = true) {
        self.isConfiguredToReturn = isConfiguredToReturn
    }

    public func isConfigured() -> Bool {
        isConfiguredToReturn
    }

    public func track(_ event: AnalyticsEvent) async {
        await trackedEvents.record(event)
    }
}
