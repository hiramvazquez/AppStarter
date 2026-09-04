import AppFoundation
import SwiftUI

/// The brand's `ErrorViewStyle` (PRD-APP-02 tramo B item 2). Installed on `RootView`
/// when `Settings`' "tema de marca" toggle is on; the kit's own `DefaultErrorStyle`
/// otherwise. `Diagnostics`' error state (manual verification, `README.md`) is
/// screenshotted under both, since it's the one screen this app deliberately puts into
/// `.error` on demand.
struct BrandErrorStyle: ErrorViewStyle {
    func makeBody(configuration: ErrorConfiguration) -> some View {
        VStack(spacing: Brand.spacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Brand.accent)
            Text(configuration.error.title)
                .font(.title3.bold())
            Text(configuration.error.message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let retry = configuration.error.retry {
                Button("Reintentar", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.accent)
            }
        }
        .padding(Brand.spacing)
    }
}
