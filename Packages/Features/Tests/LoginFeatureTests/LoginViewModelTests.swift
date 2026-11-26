import AppFoundation
import Domain
import Foundation
import Networking
import Observation
import PlatformTestSupport
import Testing

@testable import LoginFeature

/// `LoginViewModel` tested only against `LoginLogicMock` — no `AuthService`/
/// `SessionStore` real, no network involved.
@Suite("LoginViewModel")
@MainActor
struct LoginViewModelTests {
    @Test("handle(.login) calls logic.login and routes to .products on success")
    func loginRoutesToProducts() async {
        let mock = LoginLogicMock()
        let router = Coordinator<AppRoute>(root: .login)
        let sessionState = AppSessionState(router: router)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: sessionState)

        viewModel.handle(.updateUsername("emilys"))
        viewModel.handle(.updatePassword("emilyspass"))
        viewModel.handle(.login)
        await viewModel.inFlightActivity?.value

        #expect(await mock.logins.calls == ["emilys"])
        #expect(viewModel.isPerformingActivity == false)
        #expect(router.mainStack.root == .products)
    }

    @Test("un login rechazado deja el formulario a la vista")
    func loginRechazadoDejaElFormulario() async {
        await exigirFormularioALaVista(tras: .invalidCredentials, usuario: "emilys")
    }

    @Test("un campo vacío sale por el mismo camino que el rechazo")
    func campoVacioSalePorElMismoCamino() async {
        await exigirFormularioALaVista(tras: .emptyUsername, usuario: "")
    }

    /// Lo que tiene que quedar tras un login que falla, lo rechace el servidor o la validación
    /// local. La fase NO se mueve: con `.error` el contenedor de pantalla oculta el formulario,
    /// y como estos errores no son reintentables tampoco pinta botón — el usuario se queda sin
    /// forma de corregir lo que tecleó. El aviso sale en el banner, encima del formulario.
    private func exigirFormularioALaVista(tras error: LoginError, usuario: String) async {
        let mock = LoginLogicMock()
        mock.errorToThrow = error
        let router = Coordinator<AppRoute>(root: .login)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: AppSessionState(router: router))

        viewModel.handle(.updateUsername(usuario))
        viewModel.handle(.updatePassword("wrong"))
        viewModel.handle(.login)
        await viewModel.inFlightActivity?.value

        #expect(await mock.logins.calls == [usuario])
        #expect(viewModel.hasError == false)
        #expect(viewModel.isIdle)
        #expect(viewModel.isPerformingActivity == false)
        #expect(viewModel.banner?.message == error.screenError.message)
        #expect(viewModel.username == usuario)
        #expect(router.mainStack.root == .login)
    }

    @Test("tras un fallo, un segundo intento entra")
    func segundoIntentoTrasUnFallo() async {
        // A nivel de view model esto ya funcionaba cuando el envío iba por `performLoad`: lo que
        // impedía reintentar era la vista, que escondía el botón. Se fija como regresión de que
        // un fallo no deja al view model rechazando el siguiente envío.
        let mock = LoginLogicMock()
        mock.errorToThrow = LoginError.invalidCredentials
        let router = Coordinator<AppRoute>(root: .login)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: AppSessionState(router: router))
        viewModel.handle(.updateUsername("emilys"))
        viewModel.handle(.updatePassword("wrong"))

        viewModel.handle(.login)
        await viewModel.inFlightActivity?.value

        mock.errorToThrow = nil
        viewModel.handle(.updatePassword("emilyspass"))
        viewModel.handle(.login)
        await viewModel.inFlightActivity?.value

        #expect(await mock.logins.calls.count == 2)
        #expect(router.mainStack.root == .products)
    }

    @Test("un login cancelado deja la pantalla en un estado del que se puede salir")
    func loginCancelado() async {
        BaseViewModel.cancellationRecognizer = RecognizerDePrueba()
        let mock = LoginLogicMock()
        mock.errorToThrow = LoginError.cancelled
        let router = Coordinator<AppRoute>(root: .login)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: AppSessionState(router: router))

        viewModel.handle(.updateUsername("emilys"))
        viewModel.handle(.updatePassword("emilyspass"))
        viewModel.handle(.login)
        await viewModel.inFlightActivity?.value

        // `hasError == false` NO basta: también es cierto con el indicador colgado sobre el
        // formulario para siempre, sin forma de volver a intentarlo. Lo que se fija es que se
        // pueda SALIR.
        #expect(viewModel.hasError == false)
        #expect(viewModel.isPerformingActivity == false)
        #expect(viewModel.isIdle)
        #expect(router.mainStack.root == .login, "cancelar no navega")
    }

    @Test("un login superado no le quita el indicador al que lo superó")
    func loginSuperadoNoResetealaGanador() async {
        // El primer login se queda esperando en la puerta; el segundo lo cancela al arrancar.
        // Cuando el primero se desenrolla con `.cancelled`, su `Task` YA está cancelada: sin el
        // `if !Task.isCancelled` del ViewModel, le retiraría el indicador al segundo, que sigue
        // en vuelo.
        BaseViewModel.cancellationRecognizer = RecognizerDePrueba()
        let mock = LoginLogicMock()
        let primeraPuerta = Puerta()
        let segundaPuerta = Puerta()
        mock.gate = { llamada in
            await (llamada == 1 ? primeraPuerta : segundaPuerta).esperar()
        }
        mock.errorToThrow = LoginError.cancelled
        let router = Coordinator<AppRoute>(root: .login)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: AppSessionState(router: router))
        viewModel.handle(.updateUsername("emilys"))
        viewModel.handle(.updatePassword("emilyspass"))

        viewModel.handle(.login)
        let primero = viewModel.inFlightActivity

        viewModel.handle(.login)  // cancela el primero y arranca el segundo
        await primeraPuerta.abrir()
        await primero?.value

        #expect(viewModel.isPerformingActivity, "el segundo login sigue en vuelo")

        await segundaPuerta.abrir()  // se suelta para no dejar la Task colgada
        await viewModel.inFlightActivity?.value
    }

    @Test("appear() shows a banner once when the session expired, then clears the flag")
    func appearShowsExpiryBannerOnce() async {
        let mock = LoginLogicMock()
        let router = Coordinator<AppRoute>(root: .login)
        let sessionState = AppSessionState(router: router)
        await sessionState.sessionDidExpire()
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: sessionState)

        viewModel.handle(.appear)
        #expect(viewModel.banner != nil)

        viewModel.dismissBanner()
        viewModel.handle(.appear)
        #expect(viewModel.banner == nil)
    }

    @Test("Changing username notifies Observation — LoginViewModel declares its own @Observable (§11)")
    func changingUsernameNotifiesObservation() {
        let mock = LoginLogicMock()
        let router = Coordinator<AppRoute>(root: .login)
        let viewModel = LoginViewModel(logic: mock, router: router, sessionState: AppSessionState(router: router))
        let flag = ObservationFlag()

        withObservationTracking {
            _ = viewModel.username
        } onChange: {
            flag.fired = true
        }
        viewModel.handle(.updateUsername("emilys"))

        #expect(flag.fired)
    }
}
