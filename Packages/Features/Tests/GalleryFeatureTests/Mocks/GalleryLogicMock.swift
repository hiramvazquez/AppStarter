import Foundation

@testable import GalleryFeatureCore

/// Spy that substitutes `GalleryLogicProtocol` in `GalleryViewModelTests` — the ViewModel
/// under test never touches a real `GalleryLogic`.
final class GalleryLogicMock: GalleryLogicProtocol {
    private(set) var loadCallCount = 0
    var stateToReturn = GalleryState(title: "", images: [])
    var errorToThrow: (any Error)?

    private(set) var prefetchedURLs: [URL] = []

    func load(productID: Int) async throws -> GalleryState {
        loadCallCount += 1
        if let errorToThrow { throw errorToThrow }
        return stateToReturn
    }

    func prefetchImage(url: URL) async {
        prefetchedURLs.append(url)
    }
}
