import AppFoundation
import SwiftUI

/// The brand's `BannerViewStyle` (PRD-APP-02 tramo B item 2). Installed on `RootView`
/// when `Settings`' "tema de marca" toggle is on; the kit's own `DefaultBannerStyle`
/// otherwise.
struct BrandBannerStyle: BannerViewStyle {
    func makeBody(configuration: BannerConfiguration) -> some View {
        HStack {
            Text(configuration.banner.message)
            Spacer()
            Button("Cerrar", action: configuration.dismiss)
                .font(.caption)
        }
        .padding(Brand.spacing)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Brand.spacing)
    }
}
