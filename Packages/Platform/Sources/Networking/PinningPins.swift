import CoreNetworking
import Foundation

/// The pins `Settings`' "pinning estricto" toggle wires into the authenticated
/// `APIService` (PRD-APP-02 tramo B item 2) — real ones for `dummyjson.com`, and one
/// deliberately wrong pin to demonstrate `APIError.Category.untrustedServer` (never
/// `.cancelled` — see `TransportError`'s own doc comment on that distinction) when
/// "pin falso" is also on. Documented in `README.md` alongside the exact `openssl`
/// command that produced them, per the PRD.
enum PinningPins {
    /// The leaf certificate's SPKI pin — rotates on every certificate renewal.
    static let leaf = "q79YST4pUwa2CDkfrlOfH4rDdgrCXfQDLmtZeEBEk3w="

    /// The issuing intermediate's SPKI pin (Google Trust Services `WE1`) — the RFC 7469
    /// §2.5 "backup pin": survives a leaf rotation, so this pair doesn't lock the app
    /// out the next time DummyJSON renews its certificate.
    static let intermediate = "kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4="

    /// Valid base64 of exactly 32 bytes (passes `SSLPinningConfiguration
    /// .validatePins(_:)`'s shape check) but matches no real key — any request made
    /// with this pin installed fails `.untrustedServer`.
    static let fake = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    /// Builds the pinning configuration `NetworkingModule` installs on the authenticated
    /// (and unauthenticated login/refresh) `APIService`, from the persisted `AppSettings`
    /// — `nil` when pinning is off, matching `URLSessionTransport`'s own `pinning: nil`
    /// default (system TLS validation only).
    static func configuration(for settings: AppSettings, host: String) -> SSLPinningConfiguration? {
        guard settings.pinningStrict else { return nil }
        let pins = settings.useFakePin ? [fake, intermediate] : [leaf, intermediate]
        return SSLPinningConfiguration(publicKeyHashes: pins, hosts: .only([host]))
    }
}
