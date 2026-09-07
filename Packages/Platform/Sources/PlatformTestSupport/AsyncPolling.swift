import Foundation

/// Espera a que `condition` se cumpla, sondeando, con un plazo máximo.
///
/// Por qué sondear y no esperar un `Task` concreto: hay trabajo cuyo `Task` es PRIVADO del
/// view model —`.run(_:)` de Diagnostics lo guarda en `experimentTasks`, y la variante
/// estructurada de `activity()` que usa Uploads no expone handle— así que un test no puede
/// alcanzarlo para esperarlo. Lo que sí puede es mirar el estado observable, que es además
/// lo que le importa a la pantalla.
///
/// El plazo NO es un `sleep` disfrazado: en el caso bueno vuelve en el primer sondeo, y en
/// el malo el test falla por su propia aserción —la que venga después de este `await`— en
/// vez de colgarse. Un test que se cuelga se lleva la suite entera por delante y no dice
/// por qué.
///
/// Vive aquí, y no en cada target, porque `PlatformTestSupport` es donde va lo que
/// necesitan dos o más `*FeatureTests` (ver `Packages/Platform/Package.swift`). Estaba
/// escrito dos veces, idéntico, y el segundo doc comment citaba al primero.
public func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @MainActor () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while await !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
