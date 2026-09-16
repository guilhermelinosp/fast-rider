# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
versionamento semântico ([SemVer](https://semver.org/lang/pt-BR/)).

## [Unreleased]

### Adicionado
- Infraestrutura de repo: `.editorconfig`, `.gitattributes`, `.aiignore`,
  `lefthook` hooks, CI GitHub Actions (analyze + test + build iOS),
  templates de issue/PR, Dependabot, `CONTRIBUTING.md` e `LICENSE` (MIT).
- Projeto limitado a **iOS**: target Android removido.

## [1.0.0] - data

### Adicionado
- Busca de endereços via Nominatim (explícita, com desambiguação).
- Rota viária via OSRM (perfil driving) com geometria no mapa.
- Mapa OpenStreetMap read-only com `flutter_map`, marcadores, polilinha e
  atribuição obrigatória.
- Solicitação de corrida ao backend (`POST /api/v1/rides`) com identidade
  `rider_id` (UUID v4) persistida em `shared_preferences`.
- Tratamento de erros HTTP com `error.code`/`message`/`requestId`.
- Suíte de testes (7 suítes) cobrindo contrato, parsing, fluxo e UI.