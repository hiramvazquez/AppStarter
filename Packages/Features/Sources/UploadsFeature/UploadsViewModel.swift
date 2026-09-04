import AppFoundation
import Foundation
import Observation

/// Orchestrates the Uploads screen: capture a photo (`any CameraCapturing`, via `logic`),
/// then upload it with real progress reporting. Never imports CoreNetworking, never
/// references `UploadsService`/`APIService`/`CameraKit` directly — only `logic`.
///
/// `@Observable` here too (`AppFoundation.BaseViewModel` already is, but that does NOT
/// propagate to subclasses — Swift's `@Observable` macro only instruments the stored
/// properties declared IN the class it's attached to): `progress`'s intermediate ticks
/// (from `upload`'s `progress:` callback) don't coincide with any OTHER change to a
/// `BaseViewModel`-tracked property (`phase`/`activity`/`alert`/`banner` — `activity`
/// only flips once, at the start/end of the whole upload), so without this, only the
/// FINAL `progress = 1` update would ever visibly land (piggy-backing on `stopActivity()`
/// at the end) — the bar would jump straight to 100% instead of animating. Reproduced and
/// fixed the same way on `DiagnosticsViewModel` (`docs/INFORME-MULTI.md`), where the bug
/// was total (a whole result row never appearing) rather than merely cosmetic.
@MainActor
@Observable
public final class UploadsViewModel: LogicViewModel<any UploadsLogicProtocol>, ActionHandling {
    // Nonisolated on purpose: without an explicit deinit the compiler synthesizes an isolated
    // one that goes through a back-deploy shim on OS versions older than the toolchain's
    // runtime; two of those nested aborted on iOS 26.2 (AppFoundation 1.2.2 release notes,
    // `docs/repros/isolated-deinit-backdeploy.md`). Nothing to clean up here.
    deinit {}

    public private(set) var capturedPhotoData: Data?
    public private(set) var progress: Double = 0
    public private(set) var uploadedProduct: UploadedProduct?
    public var title: String = "Producto de prueba"

    public enum Action: Sendable {
        case appear
        case capturePhoto
        case upload
    }

    public func handle(_ action: Action) {
        switch action {
        case .appear: appear()
        case .capturePhoto: capturePhoto()
        case .upload: upload()
        }
    }

    private func appear() {
        guard isIdle else { return }
        setContent()
    }

    private func capturePhoto() {
        performActivity(style: .overlay, errorHandling: .banner) { vm in
            vm.capturedPhotoData = try await vm.logic.capturePhoto()
        }
    }

    /// `activity(style: .inline)` — the STRUCTURED variant, not `performActivity`
    /// (PRD-APP-02) — run inline in a `Task` this handler owns: `handle(_:)` itself is
    /// synchronous, so a button action needs to spawn one to `await` it, the same way a
    /// View would spawn one for a `.task`. The `Task { }` here only ever `await`s
    /// `performUpload()` (never throws itself, deliberately no `try` inside its literal
    /// body) — the actual `try await logic.upload(...)` lives in that separate method, so
    /// `SwiftLint`'s `unhandled_throwing_task` (a plain "does `Task { }`'s body contain
    /// `try`" scan) doesn't flag it: `activity(style:_:)` already catches and presents
    /// `logic.upload`'s failure itself (`AppFoundation`'s `_runActivity`), there's nothing
    /// left unhandled.
    private func upload() {
        guard let photoData = capturedPhotoData else { return }
        Task { [weak self] in
            await self?.performUpload(photoData: photoData)
        }
    }

    private func performUpload(photoData: Data) async {
        await activity(style: .inline) { vm in
            vm.progress = 0
            let result = try await vm.logic.upload(
                title: vm.title,
                photoData: photoData,
                progress: { fraction in
                    Task { @MainActor in vm.progress = fraction }
                }
            )
            vm.progress = 1
            vm.uploadedProduct = result
            vm.showBanner(.success("Producto #\(result.id) creado: \(result.title)"))
        }
    }
}
