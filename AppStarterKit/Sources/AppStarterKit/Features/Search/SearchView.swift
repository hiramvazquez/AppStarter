import AppFoundation

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` bound to `SearchViewModel`, presented as a sheet from `Products`
/// (`router.present(.search, as: .sheet)`). Native chrome + `.searchable` — never
/// references `SearchLogic`/`ProductsService` directly.
public struct SearchView: View {
    @State private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(viewModel) { send in
            List(viewModel.results) { product in
                Button {
                    send(.selectProduct(id: product.id))
                } label: {
                    ProductRow(product: product)
                }
                .buttonStyle(.plain)
            }
            .accessibilityIdentifier("search.results")
            .searchable(
                text: Binding(get: { viewModel.query }, set: { send(.updateQuery($0)) }),
                prompt: "Buscar productos"
            )
            .onSubmit(of: .search) { send(.submit) }
        }
        .navigationTitle("Buscar")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { viewModel.handle(.close) }
                    .accessibilityIdentifier("search.close")
            }
        }
    }
}
#endif

// MARK: - Preview: a stub, no real network pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private final class SearchPreviewLogic: SearchLogicProtocol {
    func search(query: String) async throws -> [Product] { [] }
}

#Preview {
    NavigationStack {
        SearchView(viewModel: SearchViewModel(logic: SearchPreviewLogic(), router: Coordinator<AppRoute>(root: .products)))
    }
}
#endif
