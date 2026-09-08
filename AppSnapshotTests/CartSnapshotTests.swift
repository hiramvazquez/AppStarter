import AppFoundation
import Domain
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest

@testable import CartFeature

/// `CartView` con datos, y las fases de vacío y error.
///
/// DOS FORMAS DE FOTOGRAFIAR, y la razón está medida. Un snapshot de `CartView` en `.empty`
/// o `.error` sale EN BLANCO: al renderizar, su `.task { send(.load) }` relanza la carga y
/// la captura se queda con ese estado transitorio en vez del que montó el test. Se aisló con
/// seis variantes: `List`, `ScrollView`, `VStack` y `List` con `navigationTitle` pintan el
/// overlay —un mismo hash—; `List` con `.task` y `CartView` entera dan otro, el PNG en
/// blanco. Por eso las dos fases se fotografían sobre `CartContent`, que es el mismo cuerpo
/// sin el disparador.
///
/// El contenido sí va por `CartView` entera, que es como se ve en la app.
///
/// Y por eso el contenido va en UN tema y no en dos: `snapshotTheme(.brand)` solo sustituye
/// los estilos de loading/error/empty/banner, que la fase `.content` no usa — las dos
/// referencias salían byte a byte idénticas y el eje "dos temas" no aseveraba nada ahí. En
/// vacío y error sí difieren, y ahí es donde se prueban los dos.
@MainActor
final class CartSnapshotTests: XCTestCase {
    private enum StubOutcome {
        case content
        case empty
        case failure
    }

    private final class StubLogic: CartLogicProtocol, @unchecked Sendable {
        let outcome: StubOutcome

        init(outcome: StubOutcome) {
            self.outcome = outcome
        }

        func load(userId: Int) async throws -> Cart {
            switch outcome {
            case .content:
                return Cart(
                    lines: [
                        CartLine(
                            id: 168,
                            title: "Charger SXY 21",
                            unitPrice: 540.00,
                            quantity: 3,
                            discountedTotal: 1481.20,
                            thumbnailURL: nil
                        ),
                        CartLine(
                            id: 78,
                            title: "Apple MacBook Pro 14 Inch Space Grey",
                            unitPrice: 1999.99,
                            quantity: 1,
                            discountedTotal: 1798.99,
                            thumbnailURL: nil
                        )
                    ],
                    discountedTotal: 3280.19,
                    totalQuantity: 4
                )
            case .empty:
                return .empty
            case .failure:
                throw CartError.server
            }
        }
    }

    private func makeViewModel(outcome: StubOutcome) async -> CartViewModel {
        let vm = CartViewModel(logic: StubLogic(outcome: outcome), userId: 1)
        vm.handle(.load)
        await vm.inFlightLoad?.value
        return vm
    }

    private func captura(
        _ view: some View,
        theme: SnapshotTheme,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let themed = view
            .snapshotTheme(theme)
            .frame(width: snapshotDeviceSize.width, height: snapshotDeviceSize.height)
        assertSnapshot(
            of: themed,
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                layout: .fixed(width: snapshotDeviceSize.width, height: snapshotDeviceSize.height)
            ),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    func testContentKit() async {
        let vm = await makeViewModel(outcome: .content)
        captura(CartView(viewModel: vm), theme: .kit, named: "kit")
    }

    func testEmptyKit() async {
        let vm = await makeViewModel(outcome: .empty)
        captura(ScreenContainer(vm) { _ in CartContent(cart: vm.cart) }, theme: .kit, named: "kit")
    }

    func testEmptyBrand() async {
        let vm = await makeViewModel(outcome: .empty)
        captura(ScreenContainer(vm) { _ in CartContent(cart: vm.cart) }, theme: .brand, named: "brand")
    }

    func testErrorKit() async {
        let vm = await makeViewModel(outcome: .failure)
        captura(ScreenContainer(vm) { _ in CartContent(cart: vm.cart) }, theme: .kit, named: "kit")
    }

    func testErrorBrand() async {
        let vm = await makeViewModel(outcome: .failure)
        captura(ScreenContainer(vm) { _ in CartContent(cart: vm.cart) }, theme: .brand, named: "brand")
    }
}
