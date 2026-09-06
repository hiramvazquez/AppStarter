# Swift y SwiftUI — reglas de código

Adaptado de [SwiftAgents](https://github.com/twostraws/SwiftAgents) (Paul Hudson).
**Ojo:** el original apunta a **iOS 26+**; esta app despliega en **iOS 17**, así que las
reglas que exigen APIs más nuevas están marcadas como NO aplicables.

Medido el 2026-09-05 sobre los 88 ficheros Swift de este repo: **cero infracciones**. Esto
no es una lista de deuda, es una barandilla para el código que se escriba a partir de ahora.

## Swift

- `@Observable` marcado `@MainActor` (salvo aislamiento por defecto del módulo).
- Nada de `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`,
  `@EnvironmentObject`.
- `async/await` antes que closures, siempre que exista la variante.
- Nada de GCD (`DispatchQueue.main.async`).
- Foundation moderna: `URL.documentsDirectory`, `appending(path:)`.
- `FormatStyle`, nunca subclases de `Formatter`.
- Filtrado de texto del usuario con `localizedStandardContains()`.
- Sin force unwrap ni `try!` salvo que sea irrecuperable.

## SwiftUI

- `foregroundStyle()`, no `foregroundColor()`.
- `clipShape(.rect(cornerRadius:))`, no `cornerRadius()`.
- `NavigationStack` + `navigationDestination(for:)`.
- `Task.sleep(for:)`, no `sleep(nanoseconds:)`.
- `onChange()` en su variante de dos parámetros.
- `Button` antes que `onTapGesture()` (salvo que necesites posición o número de toques).
- Nada de `UIScreen.main.bounds`, `AnyView`, ni `GeometryReader` si hay alternativa.
- Subvistas en `struct View` propios, no en propiedades computadas.
- Dynamic Type: no fijes tamaños de fuente.
- `.scrollIndicators(.hidden)` para ocultar indicadores.
- Lógica de vista en el view model, para que se pueda testear.
- Sin colores de UIKit en SwiftUI.

## NO aplicables a este proyecto (iOS 17)

- ~~`Tab` API en vez de `tabItem()`~~ — requiere iOS 18.
- ~~"usa las ScrollView APIs más nuevas"~~ — `ScrollPosition` es iOS 18.
- ~~"target iOS 26.0 o superior"~~ — este proyecto despliega en iOS 17.

## Este proyecto, además

- La arquitectura manda: ver `AGENTS.md` (capas, imports permitidos, R13/R16) y
  `.archlint.yml`. Donde SwiftAgents y `AGENTS.md` discrepen, gana `AGENTS.md`.
- SwiftLint sin avisos antes de commitear.
- SwiftData: solo `DiagnosticsFeature`. Si algún día va a CloudKit, aplican las tres
  reglas del original (nada de `@Attribute(.unique)`, propiedades con default u opcionales,
  relaciones opcionales).
