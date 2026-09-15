# CLAUDE.md

@AGENTS.md

Las reglas propias de los dos kits de los que depende el proyecto, AppFoundation y
CoreNetworking, también van en contexto en cada sesión: su `AGENTS.md` y el artículo de testing
de AppFoundation. Donde discrepen del `AGENTS.md` del proyecto (arriba), gana el del proyecto,
igual que con cualquier guía general. Vienen del checkout de SPM de `Packages/Platform` y siguen
la versión que el proyecto resuelve: en un clon recién hecho no existen hasta
`cd Packages/Platform && swift package resolve`. `/context` enseña si se cargaron.

@Packages/Platform/.build/checkouts/AppFoundation/AGENTS.md
@Packages/Platform/.build/checkouts/CoreNetworking/AGENTS.md
@Packages/Platform/.build/checkouts/AppFoundation/Sources/AppFoundation/Documentation.docc/Testing.md

Toda la lógica de negocio vive en `Packages/Platform` (Domain/Networking/Kits/Adapters) y
`Packages/Features` (un target real por feature) — cada uno con su propio `Package.swift`,
`.archlint.yml` y `swift build`/`swift test` independientes de Xcode. `App/` es la cáscara
fina que gestiona xcodegen (composition root + navegación); no tiene `Package.swift`
propio ni lógica de negocio. `AGENTS.md` (arriba) documenta la tabla real de módulos y sus
imports permitidos/prohibidos (R13).
