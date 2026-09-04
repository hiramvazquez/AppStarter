import AppFoundation
import SwiftUI

// One concrete type per style that switches between the kit's default and the brand
// style at render time. Installing these ONCE in `RootView` keeps the view identity stable
// when the theme toggles: an `if isBrand { view.styles } else { view }` would rebuild the
// whole `CoordinatorView` (and its navigation stack) on every flip.

struct ThemedLoadingStyle: LoadingViewStyle {
    let isBrand: Bool
    func makeBody(configuration: LoadingConfiguration) -> some View {
        if isBrand {
            BrandLoadingStyle().makeBody(configuration: configuration)
        } else {
            DefaultLoadingViewStyle().makeBody(configuration: configuration)
        }
    }
}

struct ThemedErrorStyle: ErrorViewStyle {
    let isBrand: Bool
    func makeBody(configuration: ErrorConfiguration) -> some View {
        if isBrand {
            BrandErrorStyle().makeBody(configuration: configuration)
        } else {
            DefaultErrorViewStyle().makeBody(configuration: configuration)
        }
    }
}

struct ThemedEmptyStyle: EmptyViewStyle {
    let isBrand: Bool
    func makeBody(configuration: EmptyConfiguration) -> some View {
        if isBrand {
            BrandEmptyStyle().makeBody(configuration: configuration)
        } else {
            DefaultEmptyViewStyle().makeBody(configuration: configuration)
        }
    }
}

struct ThemedBannerStyle: BannerViewStyle {
    let isBrand: Bool
    func makeBody(configuration: BannerConfiguration) -> some View {
        if isBrand {
            BrandBannerStyle().makeBody(configuration: configuration)
        } else {
            DefaultBannerViewStyle().makeBody(configuration: configuration)
        }
    }
}
