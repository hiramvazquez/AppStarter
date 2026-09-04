import Foundation

/// A tiny mutable box for `withObservationTracking`'s `onChange` callback (`@Sendable`,
/// fires synchronously on the same thread as the mutation it observed — never needs an
/// `await`/`Task`/timeout to read afterward). Same shape as `AppFoundationTests
/// .ObservationInheritanceTests`' own private `Flag` (PRD-AF-11 A0, the upstream test for
/// "`@Observable` is not inherited") — shared here because every `*FeatureTests` target
/// that verifies its ViewModel's OWN `@Observable` (PRD-APP-02 tramo B item 0: every
/// ViewModel in this repo declares it) needs the exact same helper, not six private copies.
public nonisolated final class ObservationFlag: @unchecked Sendable {
    public nonisolated(unsafe) var fired = false

    public init() {}
}
