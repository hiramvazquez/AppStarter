import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

/// La pantalla de carrito. Solo conoce el ViewModel a través de `ScreenContainer` — nunca
/// referencia `CartLogic`, `CartService` ni `APIService`.
public struct CartView: View {
    // La compone el composition root; la vista la RETIENE. `@State` mantiene viva la misma
    // instancia cuando SwiftUI vuelve a ejecutar este init (el builder de un destino de
    // navegación lo hace al empujar): con `let`, la instancia que recibió `.load` podría
    // ser sustituida por otra que nunca lo recibe, dejando la pantalla vacía y sin error.
    @State private var viewModel: CartViewModel

    public init(viewModel: CartViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            CartContent(cart: viewModel.cart)
                .task { send(.load) }
        }
        .navigationTitle("Carrito")
    }
}

/// El cuerpo de la pantalla, separado de `CartView` para poder fotografiarlo SIN el
/// `.task` que dispara la carga.
///
/// No es una separación cosmética. Un snapshot de `CartView` en fase `.empty` o `.error`
/// sale EN BLANCO: al renderizar, el `.task` relanza la carga y la captura se queda con ese
/// estado transitorio en vez del que montó el test. Medido con seis variantes — `List`,
/// `ScrollView`, `VStack` y `List` con `navigationTitle` pintan el overlay (un mismo hash);
/// `List` con `.task` y `CartView` entera dan el PNG en blanco (otro hash) —. `GalleryView`
/// tiene el mismo `.task { send(.load) }` y las mismas cuatro referencias en blanco;
/// `DiagnosticsView`/`UploadsView` mandan `.appear` y no les pasa.
///
/// `internal`, no `public`: lo usa la pantalla y lo fotografían los tests de la app, nadie
/// más.
struct CartContent: View {
    let cart: Cart

    var body: some View {
        List {
            Section {
                ForEach(cart.lines) { line in
                    CartLineRow(line: line)
                }
            } footer: {
                CartTotalFooter(cart: cart)
            }
        }
    }
}

/// Una línea: qué es, cuántas unidades y lo que suma con el descuento aplicado.
///
/// La cantidad y el total van juntos y no son decorativos: la spec exige que la pantalla
/// diga lo que se va a pagar, no solo el precio unitario de cada cosa.
private struct CartLineRow: View {
    let line: CartLine

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: line.thumbnailURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                Text("\(line.quantity) × \(line.unitPrice.formatted(.currency(code: "USD")))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(line.discountedTotal.formatted(.currency(code: "USD")))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// El total del carrito, con las unidades que lo componen.
private struct CartTotalFooter: View {
    let cart: Cart

    var body: some View {
        HStack {
            // NO se usa `^[...](inflect: true)`: la concordancia automática necesita un
            // catálogo de strings localizado, y esta app escribe los literales en español
            // a pelo. Sin catálogo, la inflexión no se aplica y la pantalla decía
            // "4 artículo". Lo destapó mirar la imagen del snapshot recién grabado; los
            // tests estaban en verde, porque un snapshot recién grabado siempre lo está.
            Text(cart.totalQuantity == 1 ? "1 artículo" : "\(cart.totalQuantity) artículos")
            Spacer()
            Text(cart.discountedTotal.formatted(.currency(code: "USD")))
                .monospacedDigit()
                .fontWeight(.semibold)
        }
    }
}
#endif

// MARK: - Preview: un stub, nunca usado fuera de DEBUG (mismo patrón que el resto de
// features — este andamiaje está exento de las reglas de capas, `ArchLint.R4` incluida).

#if canImport(SwiftUI) && DEBUG
/// Stub de `CartLogicProtocol` solo para el `#Preview`. La spy con contadores para los
/// tests (M9) es `CartLogicMock`, en el target de tests.
private nonisolated final class CartPreviewLogic: CartLogicProtocol {
    func load(userId: Int) async throws -> Cart {
        Cart(
            lines: [
                CartLine(
                    id: 162,
                    title: "Blue Frock",
                    unitPrice: 29.99,
                    quantity: 4,
                    discountedTotal: 105.41,
                    thumbnailURL: nil
                )
            ],
            discountedTotal: 105.41,
            totalQuantity: 4
        )
    }
}

#Preview {
    NavigationStack {
        CartView(viewModel: CartViewModel(logic: CartPreviewLogic(), userId: 1))
    }
}
#endif
