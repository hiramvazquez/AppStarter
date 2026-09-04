import AppFoundation
import SwiftUI

/// The brand's `LoadingViewStyle` (PRD-APP-02 tramo B item 2). Installed on
/// `RootView` when `Settings`' "tema de marca" toggle is on; the kit's own
/// `DefaultLoadingStyle` otherwise.
struct BrandLoadingStyle: LoadingViewStyle {
    func makeBody(configuration: LoadingConfiguration) -> some View {
        switch configuration.style {
        case .fullScreen:
            ProgressView().tint(Brand.accent).scaleEffect(1.4)
        case .inline, .overlay:
            ProgressView().tint(Brand.accent)
        }
    }
}
