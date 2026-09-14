import Foundation

@testable import GalleryFeatureCore

/// Spy that substitutes `GalleryLogicProtocol` in `GalleryViewModelTests` — the ViewModel
/// under test never touches a real `GalleryLogic`.
final class GalleryLogicMock: GalleryLogicProtocol {
    private(set) var loadCallCount = 0
    var stateToReturn = GalleryState(title: "", images: [])
    var errorToThrow: (any Error)?

    /// Deja parada una llamada concreta. Recibe el número de llamada (1, 2, …) para poder
    /// soltar UNA y dejar la otra en vuelo, que es lo que hace falta para observar qué le pasa
    /// a la fase cuando una carga supera a otra. Mismo mecanismo que `CartLogicMock`.
    var gate: (@Sendable (Int) async -> Void)?

    private(set) var prefetchedURLs: [URL] = []

    func load(productID: Int) async throws -> GalleryState {
        loadCallCount += 1
        let llamada = loadCallCount
        await gate?(llamada)
        if let errorToThrow { throw errorToThrow }
        return stateToReturn
    }

    func prefetchImage(url: URL) async {
        prefetchedURLs.append(url)
    }
}
