import AppFoundation
import Domain

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `ProductsViewModel`: a paginated, pull-to-refreshable list
/// of DummyJSON products, with toolbar entry points to Search (sheet), Favorites and
/// Profile (both pushed). Native chrome — never references `ProductsLogic`/
/// `ProductsService`/`APIService`.
public struct ProductsView: View {
    @State private var viewModel: ProductsViewModel

    public init(viewModel: ProductsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            List {
                ForEach(viewModel.items) { product in
                    Button {
                        send(.selectProduct(id: product.id))
                    } label: {
                        ProductRow(product: product)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("product.\(product.id)")
                    .onAppear {
                        if product.id == viewModel.items.last?.id {
                            send(.loadMore)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable { send(.refresh) }
            .accessibilityIdentifier("products.list")
            .onAppear { send(.load) }
        }
        .navigationTitle("Productos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.handle(.openSearch)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Buscar")
                .accessibilityIdentifier("products.search")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.handle(.openFavorites)
                } label: {
                    Image(systemName: "star")
                }
                .accessibilityLabel("Favoritos")
                .accessibilityIdentifier("products.favorites")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.handle(.openProfile)
                } label: {
                    Image(systemName: "person.circle")
                }
                .accessibilityLabel("Perfil")
                .accessibilityIdentifier("products.profile")
            }
        }
    }
}

/// Row rendering for a `Product`. In the single-target `AppStarterKit` this was shared
/// (`internal`) by `ProductsView`/`FavoritesView`/`SearchView`; a `*Feature` cannot import
/// another `*Feature` (R13), so each of the three duplicates this small, purely visual
/// `View` instead of introducing a shared UI module for one row — not worth a third local
/// manifest (`MultiModule.md` § "qué vigilar").
struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: product.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(product.price, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
#endif

// MARK: - Preview: a stub, no real network pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private nonisolated final class ProductsPreviewLogic: ProductsLogicProtocol {
    let pageSize = 20
    func loadPage(skip: Int) async throws -> ProductsPage {
        ProductsPage(
            items: [
                Product(
                    id: 1,
                    title: "Producto de ejemplo",
                    description: "",
                    price: 9.99,
                    rating: 4.5,
                    thumbnailURL: nil
                )
            ],
            total: 1,
            skip: 0,
            limit: pageSize
        )
    }
}

#Preview {
    NavigationStack {
        ProductsView(
            viewModel: ProductsViewModel(logic: ProductsPreviewLogic(), router: Coordinator<AppRoute>(root: .products))
        )
    }
}
#endif
