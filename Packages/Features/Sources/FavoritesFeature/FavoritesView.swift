import AppFoundation
import Domain

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `FavoritesViewModel`: the SwiftData-backed favorites list.
/// Native chrome — never references `FavoritesLogic`/`FavoritesStore`/SwiftData directly.
public struct FavoritesView: View {
    @State private var viewModel: FavoritesViewModel

    public init(viewModel: FavoritesViewModel) {
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
                    .accessibilityIdentifier("favorite.\(product.id)")
                }
                .onDelete { offsets in
                    for index in offsets {
                        send(.remove(id: viewModel.items[index].id))
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityIdentifier("favorites.list")
            .onAppear { send(.load) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        send(.clearAllRequested)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.items.isEmpty)
                    .accessibilityLabel("Vaciar favoritos")
                    .accessibilityIdentifier("favorites.clearAll")
                }
            }
        }
        .navigationTitle("Favoritos")
    }
}

/// Row rendering for a `Product` — see `ProductsFeature.ProductRow`'s doc comment for why
/// this small view is duplicated per feature instead of shared.
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

// MARK: - Preview: a stub, no real persistence pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private final class FavoritesPreviewLogic: FavoritesLogicProtocol {
    func loadFavorites() async throws -> [Product] { [] }
    func remove(id: Int) async throws {}
    func clearAll() async throws {}
}

#Preview {
    NavigationStack {
        FavoritesView(
            viewModel: FavoritesViewModel(
                logic: FavoritesPreviewLogic(),
                router: Coordinator<AppRoute>(root: .favorites)
            )
        )
    }
}
#endif
