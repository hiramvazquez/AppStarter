import SwiftUI

/// AppStarter's own maqueta, in one place (PRD-APP-02 tramo B item 2, `Theming.md`
/// §"Los cuatro estilos, una vez en la raíz"): a placeholder brand, not a real design
/// system — its only job is to look OBVIOUSLY different from the kit's own defaults, so
/// `Settings`' "tema de marca" toggle is visibly doing something (the manual
/// verification in `README.md` screenshots `Diagnostics`' error state under both).
enum Brand {
    static let accent = Color(red: 0.75, green: 0.15, blue: 0.35)
    static let surface = Color(red: 0.75, green: 0.15, blue: 0.35).opacity(0.12)
    static let spacing: CGFloat = 16
}
