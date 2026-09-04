import CoreNetworking
import CoreNetworkingTestSupport
import Foundation
import Testing

@testable import UploadsFeature

/// `UploadsService` — the only type in this feature that touches `APIServiceProtocol`/
/// `upload(_:data:progress:)` — tested against `MockAPIService`.
@Suite("UploadsService")
struct UploadsServiceTests {
    @Test("A stubbed 200 decodes the DTO into UploadedProduct")
    func stubbedSuccessDecodesProduct() async throws {
        let mock = MockAPIService()
        mock.stub(AddProductRequest.self, returning: AddProductRequest.Response(id: 101, title: "Widget"))
        let service = UploadsService(api: mock)

        let result = try await service.addProduct(title: "Widget", photoData: Data([0xFF]), progress: { _ in })

        #expect(result == UploadedProduct(id: 101, title: "Widget"))
    }

    @Test("A stubbed failure propagates as APIError")
    func stubbedFailurePropagates() async {
        let mock = MockAPIService()
        mock.stub(AddProductRequest.self, throwing: .stub(code: .httpStatus, statusCode: 500))
        let service = UploadsService(api: mock)

        do {
            _ = try await service.addProduct(title: "Widget", photoData: Data(), progress: { _ in })
            Issue.record("Expected addProduct to throw")
        } catch {
            #expect(error.statusCode == 500)
        }
    }

    @Test("An unstubbed request throws APIError.Code.unstubbed")
    func unstubbedRequestThrowsUnstubbed() async {
        let mock = MockAPIService()
        let service = UploadsService(api: mock)

        do {
            _ = try await service.addProduct(title: "Widget", photoData: Data(), progress: { _ in })
            Issue.record("Expected addProduct to throw")
        } catch {
            #expect(error.code == .unstubbed)
        }
    }
}
