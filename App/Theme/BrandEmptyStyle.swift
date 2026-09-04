import AppFoundation
import SwiftUI

/// The brand's `EmptyViewStyle` (PRD-APP-02 tramo B item 2). Installed on `RootView`
/// when `Settings`' "tema de marca" toggle is on; the kit's own `DefaultEmptyStyle`
/// otherwise.
struct BrandEmptyStyle: EmptyViewStyle {
    func makeBody(configuration: EmptyConfiguration) -> some View {
        ContentUnavailableView(
            "Nada por aquí",
            systemImage: "shippingbox",
            description: Text("Cuando haya datos, aparecerán en esta lista.")
        )
        .tint(Brand.accent)
    }
}
