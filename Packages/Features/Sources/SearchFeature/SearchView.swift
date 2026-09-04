import AppFoundation
import Domain

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

// MARK: - Preview: a stub, no real network pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private final class SearchPreviewLogic: SearchLogicProtocol {
    func search(query: String) async throws -> [Product] { [] }
}

#Preview {
    NavigationStack {
        SearchView(
            viewModel: SearchViewModel(logic: SearchPreviewLogic(), router: Coordinator<AppRoute>(root: .products))
        )
    }
}
#endif
