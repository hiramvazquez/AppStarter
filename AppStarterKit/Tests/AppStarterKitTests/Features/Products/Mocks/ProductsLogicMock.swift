import AppFoundationTestSupport
import Foundation

@testable import AppStarterKit

final class ProductsLogicMock: ProductsLogicProtocol {
    let pageSize = 20
    let loadPageCalls = SpyRecorder<Int>()
    var pageToReturn = ProductsPage(items: [], total: 0, skip: 0, limit: 20)
    var errorToThrow: (any Error)?

    func loadPage(skip: Int) async throws -> ProductsPage {
        await loadPageCalls.record(skip)
        if let errorToThrow { throw errorToThrow }
        return pageToReturn
    }
}
