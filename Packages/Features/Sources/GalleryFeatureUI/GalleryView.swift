import AppFoundation
import Domain
import GalleryFeatureCore

#if canImport(SwiftUI)
import SwiftUI

/// `ScreenContainer` with `chrome: .custom(_, placement: .overlay)` (PRD-APP-02): the
/// bar floats OVER the paging image instead of pushing it down — a `.transparent`
/// `NavigationBarStyle` so the photo shows edge-to-edge behind it, with close/share
/// `NavigationBarItem`s. `PopGestureEnabler` is installed automatically for `.custom`
/// chrome (`ScreenContainer`), so swipe-back keeps working even though the native bar is
/// gone. Never references `GalleryLogic`/`GalleryService` directly — only `logic`.
public struct GalleryView: View {
    @State private var viewModel: GalleryViewModel

    public init(viewModel: GalleryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScreenContainer(
            viewModel,
            chrome: .custom(
                NavigationBarConfiguration(
                    leftItems: [.close(id: "gallery.close", action: { viewModel.handle(.close) })],
                    rightItems: [
                        .icon("square.and.arrow.up", id: "gallery.share", action: { viewModel.handle(.share) })
                    ],
                    style: .transparent
                ),
                placement: .overlay
            )
        ) { send in
            VStack(spacing: 0) {
                TabView(
                    selection: Binding(get: { viewModel.selectedIndex }, set: { send(.select(index: $0)) })
                ) {
                    ForEach(Array(viewModel.images.enumerated()), id: \.offset) { index, url in
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.black.opacity(0.05)
                        }
                        .tag(index)
                        .accessibilityIdentifier("gallery.image.\(index)")
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .ignoresSafeArea()
                .onChange(of: viewModel.selectedIndex) { _, newIndex in
                    send(.scrolled(toIndex: newIndex))
                }

                GalleryThumbnailsView(images: viewModel.images, selectedIndex: viewModel.selectedIndex) { index in
                    send(.select(index: index))
                }
                .padding(.vertical, 12)
                .background(.black)
            }
            .background(.black)
            .task { send(.load) }
        }
        #if canImport(UIKit)
        .sheet(
            item: Binding(
                get: { viewModel.shareURL.map(ShareItem.init) },
                set: { _ in viewModel.handle(.dismissShare) }
            )
        ) { item in
            GalleryShareSheet(activityItems: [item.url])
        }
        #endif
    }
}

#if canImport(UIKit)
import UIKit

/// Wraps a `URL` as `Identifiable` — `.sheet(item:)` needs it, `URL` doesn't conform.
private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

/// `UIActivityViewController` wrapper for the share `NavigationBarItem` — SwiftUI's
/// `ShareLink` can't be driven programmatically from a `NavigationBarItem`'s `action`
/// closure (it only presents on its own tap gesture, and `CustomNavigationBar` already
/// wraps every item in its own `Button`), so `.share` sets `shareURL` and the View
/// presents this instead.
struct GalleryShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

/// The thumbnail strip below the paging image — PRD-APP-02's "caso sin ViewModel":
/// `PhaseView` driven by a plain `Binding<ViewPhase>` this view owns itself
/// (`BindingBackedState` — the type `AppFoundation` uses internally for the same
/// pattern, e.g. `ScreenContainer(phase:activity:alert:banner:...)` — has an internal
/// `init`, not part of the package's public surface; a local `@State` bound straight into
/// `PhaseView(phase:)` is the public entry point for "screen state without a ViewModel").
/// `.empty` (no thumbnails yet, before `GalleryViewModel.load()` resolves) uses the same
/// `EmptyViewStyle` every other screen's real empty state does — never a bespoke view.
struct GalleryThumbnailsView: View {
    let images: [URL]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    @State private var phase: ViewPhase = .empty

    var body: some View {
        PhaseView(phase: $phase, backgroundColor: .clear) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, url in
                        Button {
                            onSelect(index)
                        } label: {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.2)
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(index == selectedIndex ? Color.white : .clear, lineWidth: 2)
                            )
                        }
                        .accessibilityIdentifier("gallery.thumbnail.\(index)")
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 64)
        .onChange(of: images) { _, newImages in
            phase = newImages.isEmpty ? .empty : .content
        }
        .onAppear {
            phase = images.isEmpty ? .empty : .content
        }
    }
}
#endif

// MARK: - Preview: a stub, no real network pipeline (never used outside DEBUG)

#if canImport(SwiftUI) && DEBUG
private nonisolated final class GalleryPreviewLogic: GalleryLogicProtocol {
    func load(productID: Int) async throws -> GalleryState {
        GalleryState(title: "Producto de ejemplo", images: [])
    }
    func prefetchImage(url: URL) async {}
}

#Preview {
    NavigationStack {
        GalleryView(
            viewModel: GalleryViewModel(
                logic: GalleryPreviewLogic(),
                productID: 1,
                router: Coordinator<AppRoute>(root: .products)
            )
        )
    }
}
#endif
