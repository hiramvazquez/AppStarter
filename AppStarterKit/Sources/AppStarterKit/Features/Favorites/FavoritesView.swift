import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `FavoritesViewModel`: the SwiftData-backed favorites list.
/// Native chrome — never references `FavoritesLogic`/`FavoritesStore`/SwiftData directly.
public struct FavoritesView: View {
    let viewModel: FavoritesViewModel

    public init(viewModel: FavoritesViewModel) {
        self.viewModel = viewModel
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
        }
        .navigationTitle("Favoritos")
    }
}
#endif

// MARK: - Preview: a stub, no real persistence pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private final class FavoritesPreviewLogic: FavoritesLogicProtocol {
    func loadFavorites() async throws -> [Product] { [] }
    func remove(id: Int) async throws {}
}

#Preview {
    NavigationStack {
        FavoritesView(
            viewModel: FavoritesViewModel(logic: FavoritesPreviewLogic(), router: Coordinator<AppRoute>(root: .favorites))
        )
    }
}
#endif
