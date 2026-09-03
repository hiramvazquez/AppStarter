import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `ProductDetailViewModel` — the ONE screen in this app that
/// opts into `chrome: .custom` (PRD-APP-01) instead of the native bar every other screen
/// uses: it exists to prove `ScreenContainer` keeps swipe-back working
/// (`PopGestureEnabler`, installed automatically for `.custom` chrome) and that the
/// custom back button still exposes the right `accessibilityLabel` for VoiceOver — both
/// covered by `ProductDetailUITests`. Never references `ProductDetailLogic`/
/// `ProductsService`/`FavoritesStore` directly.
public struct ProductDetailView: View {
    @State private var viewModel: ProductDetailViewModel

    public init(viewModel: ProductDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(
            viewModel,
            chrome: .custom(.withBack(title: "Detalle", backAction: { viewModel.handle(.back) }))
        ) { send in
            ScrollView {
                if let product = viewModel.product {
                    VStack(alignment: .leading, spacing: 16) {
                        AsyncImage(url: product.thumbnailURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        HStack {
                            Text(product.title)
                                .font(.title2.bold())
                                .accessibilityIdentifier("productDetail.title")
                            Spacer()
                            Button {
                                send(.toggleFavorite)
                            } label: {
                                Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(.yellow)
                            }
                            .accessibilityLabel(viewModel.isFavorite ? "Quitar de favoritos" : "Añadir a favoritos")
                            .accessibilityIdentifier("productDetail.favorite")
                        }

                        Text(product.price, format: .currency(code: "USD"))
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text(product.description)
                            .font(.body)
                    }
                    // No `.accessibilityIdentifier` on this container: applying one to a
                    // `VStack` here made SwiftUI propagate it onto every descendant
                    // element (including this Button's OWN, more specific identifier
                    // below), so the whole subtree reported the CONTAINER's id instead of
                    // each element's — confirmed empirically (`docs/INFORME-INTEGRACION.md`),
                    // not documented behavior. Individual identifiers on `Text`/`Button`
                    // are what the XCUITests key on instead (`productDetail.title`,
                    // `productDetail.favorite`).
                    .padding()
                }
            }
            // `@State` above is the kit's rule (AppFoundation ≥ 1.0.1, linter R12): this
            // ViewModel is transient (one per pushed product), and SwiftUI re-runs the
            // navigation destination builder during the push — a plain `let` would drop
            // the instance that received `.load`. See `docs/INFORME-INTEGRACION.md`, friction 10.
            .task { send(.load) }
        }
    }
}
#endif

// MARK: - Preview: a stub, no real network/persistence pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private final class ProductDetailPreviewLogic: ProductDetailLogicProtocol {
    func load(id: Int) async throws -> ProductDetailState {
        ProductDetailState(
            product: Product(
                id: id,
                title: "Producto de ejemplo",
                description: "Descripción de ejemplo.",
                price: 19.99,
                rating: 4.2,
                thumbnailURL: nil
            ),
            isFavorite: false
        )
    }
    func toggleFavorite(_ product: Product) async throws -> Bool { true }
}

#Preview {
    NavigationStack {
        ProductDetailView(
            viewModel: ProductDetailViewModel(
                logic: ProductDetailPreviewLogic(),
                productID: 1,
                router: Coordinator<AppRoute>(root: .products)
            )
        )
    }
}
#endif
