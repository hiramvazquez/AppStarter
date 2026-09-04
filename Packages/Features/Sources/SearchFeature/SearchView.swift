import AppFoundation
import Domain

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` with `chrome: .custom(_, placement: .stack)` (PRD-APP-02 tramo B item
/// 4): `SearchBarConfiguration` embedded in a `.blur` `NavigationBarStyle` — the material
/// bar drives `.updateQuery` on every keystroke (debounced in `SearchViewModel`), never
/// SwiftUI's own `.searchable`. Presented as a sheet from `Products`
/// (`router.present(.search(query: nil), as: .sheet)`) or opened pre-filled by a deep link
/// (`appstarter://search?q=…`, PRD-APP-02 tramo B item 3). Never references
/// `SearchLogic`/`ProductsService` directly.
public struct SearchView: View {
    @State private var viewModel: SearchViewModel

    public init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(
            viewModel,
            chrome: .custom(
                NavigationBarConfiguration(
                    leftItems: [.close(id: "search.close", action: { viewModel.handle(.close) })],
                    searchBar: SearchBarConfiguration(
                        text: Binding(get: { viewModel.query }, set: { viewModel.handle(.updateQuery($0)) }),
                        placeholder: "Buscar productos",
                        onSubmit: { viewModel.handle(.submit) }
                    ),
                    style: .blur
                )
            )
        ) { send in
            List(viewModel.results) { product in
                Button {
                    send(.selectProduct(id: product.id))
                } label: {
                    ProductRow(product: product)
                }
                .buttonStyle(.plain)
            }
            .accessibilityIdentifier("search.results")
            // Same rule as `ProductDetailView`'s `.task { send(.load) }` (R12): a deep
            // link's pre-filled query auto-searches once, here — never on a plain "open
            // search" (empty `query`, a no-op inside `.appear`'s handler).
            .task { send(.appear) }
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
