## ADDED Requirements

### Requirement: Dónde vive un helper de test compartido

Un helper de test (mock, spy o utilidad) que necesiten **dos o más** targets `*FeatureTests`
SHALL vivir en `PlatformTestSupport`, y SHALL NOT duplicarse en cada target.

Un helper que solo use un target SHALL quedarse privado en él: mover a `PlatformTestSupport`
algo con un único consumidor convierte una decisión local en superficie pública para nadie.

#### Scenario: Un segundo target necesita un helper que ya existe

- **WHEN** un target de test necesita un helper que ya está escrito en otro target
- **THEN** el helper se mueve a `PlatformTestSupport` y ambos lo importan
- **AND** no queda ninguna copia privada

#### Scenario: Un helper con un solo consumidor

- **WHEN** solo un target de test usa un helper
- **THEN** se queda privado en ese target
