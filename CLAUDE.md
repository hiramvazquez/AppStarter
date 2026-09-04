# CLAUDE.md

@AGENTS.md

Toda la lógica de negocio vive en `Packages/Platform` (Domain/Networking/Kits/Adapters) y
`Packages/Features` (un target real por feature) — cada uno con su propio `Package.swift`,
`.archlint.yml` y `swift build`/`swift test` independientes de Xcode. `App/` es la cáscara
fina que gestiona xcodegen (composition root + navegación); no tiene `Package.swift`
propio ni lógica de negocio. `AGENTS.md` (arriba) documenta la tabla real de módulos y sus
imports permitidos/prohibidos (R13).
