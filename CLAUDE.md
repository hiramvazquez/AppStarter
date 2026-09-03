# CLAUDE.md

@AGENTS.md

Toda la lógica de negocio (Features, tests, `generate-feature`/`archlint`) vive en el
paquete local `AppStarterKit/` — sus propios `AGENTS.md`/`CLAUDE.md`/`.archlint.yml` (de
`archinit`) son la copia autoritativa para trabajar ahí dentro. Este fichero es la copia
de nivel de repo, para que un agente que arranque en la raíz vea las reglas sin tener que
saber de antemano que `AppStarterKit/` existe.
