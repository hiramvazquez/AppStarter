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
            CartContent(cart: viewModel.cart, send: send)
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
/// Recibe `send` para que las filas manden sus ediciones: lo da el `ScreenContainer` que la
/// envuelve, el de la pantalla o el de los snapshots.
///
/// `internal`, no `public`: lo usa la pantalla y lo fotografían los tests de la app, nadie
/// más.
struct CartContent: View {
    let cart: Cart
    let send: ActionSender<CartViewModel.Action>

    var body: some View {
        List {
            Section {
                ForEach(cart.lines) { line in
                    CartLineRow(line: line, send: send)
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
/// diga lo que se va a pagar, no solo el precio unitario de cada cosa. Y desde que hay
/// descuento, exige además que las dos cifras se puedan reconciliar: `4 × 29,99 $` a la
/// izquierda y `105,41 $` a la derecha no es una rebaja, es una cuenta mal hecha, hasta que
/// aparece el `119,96 $` del que sale.
///
/// Y desde que el carrito se edita, lleva sus dos controles: la cantidad y «Quitar» al
/// deslizar, los dos alcanzables también con VoiceOver.
private struct CartLineRow: View {
    let line: CartLine
    let send: ActionSender<CartViewModel.Action>

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

                // Un `Binding` sin `@State` a propósito: lo que el control enseña es
                // `line.quantity`, la cifra del servidor, y pulsar solo PIDE el cambio. Con un
                // estado local la cantidad se adelantaría a la respuesta y quedaría junto a
                // importes de la anterior. Desde 1: quitar es su propia acción, y la API deja
                // en el carrito una línea a cero.
                Stepper(
                    "Cantidad",
                    value: Binding(
                        get: { line.quantity },
                        set: { send(.setQuantity($0, lineId: line.id)) }
                    ),
                    in: 1...Int.max
                )
                .labelsHidden()
            }

            Spacer()

            // Los dos importes APILADOS, no uno al lado del otro. Se probó en horizontal y
            // el snapshot lo tumbó: tres cifras no caben a lo ancho de un iPhone junto a un
            // título como "Apple MacBook Pro 14 Inch Space Grey", y los números se partían a
            // mitad —"US$1,620.0" y un "0" suelto en la línea siguiente, con el tachado
            // cruzando las dos—. Apilados, cada cifra vuelve a caber entera, y el "antes"
            // queda justo encima del que se paga, que es como se lee una rebaja.
            VStack(alignment: .trailing, spacing: 2) {
                // Solo si hay rebaja QUE SE VEA: `hasDiscount` compara en céntimos, así que
                // una diferencia por debajo del céntimo no pinta aquí un importe idéntico al
                // de abajo, tachado y sin sentido.
                if line.hasDiscount {
                    Text(line.total.formatted(.currency(code: "USD")))
                        .strikethrough()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(line.discountedTotal.formatted(.currency(code: "USD")))
                    .monospacedDigit()
            }
        }
        // El label explícito va DESPUÉS de `.combine` para sustituir lo que compone: el
        // tachado no lo lee nadie, y sin esto la fila pasaría de dos importes ambiguos a
        // tres. Ver `CartCopy`.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CartCopy.lineAccessibilityLabel(line))
        // `.combine` no garantiza que el `Stepper` de dentro siga siendo ajustable, así que la
        // fila entera lo es: deslizar arriba o abajo con VoiceOver pide el cambio, igual que
        // el control. Bajar en 1 no hace nada, como el «−» desactivado.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                send(.setQuantity(line.quantity + 1, lineId: line.id))
            case .decrement:
                if line.quantity > 1 { send(.setQuantity(line.quantity - 1, lineId: line.id)) }
            @unknown default:
                break
            }
        }
        .accessibilityAction(named: "Quitar") { send(.removeLine(id: line.id)) }
        // `swipeActions` y no `.onDelete`: la etiqueta es «Quitar», explícita, y no depende de
        // los offsets del `ForEach`.
        //
        // SIN `role: .destructive`, a propósito. Con ese rol la lista puede animar la fila fuera
        // al pulsar, antes de que responda el servidor; si el `PUT` falla, la pantalla se quedaría
        // sin una línea que el carrito sigue teniendo. Es una sospecha del revisor que no se llegó
        // a reproducir, y se quitó por precaución (decisión del owner, 2026-09-15): el rojo lo pone
        // `.tint`, y la fila solo se va cuando se va el dato.
        .swipeActions(edge: .trailing) {
            Button("Quitar") { send(.removeLine(id: line.id)) }
                .tint(.red)
        }
    }
}

/// El total del carrito, con las unidades que lo componen y —si la hay— la rebaja que lo
/// explica.
///
/// Sin descuento se queda en la fila única de siempre: desglosar un carrito sin promoción
/// en «Subtotal / Descuento −0,00 $ / Total» es explicar una rebaja que no existe, y se
/// pagaría en cada carrito sin promoción.
private struct CartTotalFooter: View {
    let cart: Cart

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                // NO se usa `^[...](inflect: true)`: la concordancia automática necesita un
                // catálogo de strings localizado, y esta app escribe los literales en español
                // a pelo. Sin catálogo, la inflexión no se aplica y la pantalla decía
                // "4 artículo". Lo destapó mirar la imagen del snapshot recién grabado; los
                // tests estaban en verde, porque un snapshot recién grabado siempre lo está.
                Text(cart.totalQuantity == 1 ? "1 artículo" : "\(cart.totalQuantity) artículos")
                Spacer()
                if !cart.hasDiscount {
                    total
                }
            }

            if cart.hasDiscount {
                fila("Subtotal", cart.total.formatted(.currency(code: "USD")))
                fila("Descuento", "−" + cart.discountAmount.formatted(.currency(code: "USD")))
                HStack {
                    Text("Total")
                    Spacer()
                    total
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CartCopy.totalAccessibilityLabel(cart))
    }

    private var total: some View {
        Text(cart.discountedTotal.formatted(.currency(code: "USD")))
            .monospacedDigit()
            .fontWeight(.semibold)
    }

    private func fila(_ etiqueta: String, _ importe: String) -> some View {
        HStack {
            Text(etiqueta)
            Spacer()
            Text(importe).monospacedDigit()
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
            id: 1,
            lines: [
                CartLine(
                    id: 162,
                    title: "Blue Frock",
                    unitPrice: 29.99,
                    quantity: 4,
                    total: 119.96,
                    discountedTotal: 105.41,
                    thumbnailURL: nil
                )
            ],
            total: 119.96,
            discountedTotal: 105.41,
            totalQuantity: 4
        )
    }

    // Sin servidor no hay respuesta que enseñar, y la pantalla no recalcula: la preview devuelve
    // el carrito tal cual.
    func setQuantity(_ quantity: Int, ofLine lineId: Int, in cart: Cart) async throws -> Cart { cart }

    func removeLine(_ lineId: Int, from cart: Cart) async throws -> Cart { cart }
}

#Preview {
    NavigationStack {
        CartView(viewModel: CartViewModel(logic: CartPreviewLogic(), userId: 1))
    }
}
#endif
