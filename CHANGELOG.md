# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento semântico ([SemVer](https://semver.org/lang/pt-BR/)).

## [Unreleased]

## [1.0.0] - 2026-09-16

### Adicionado

- Mapa `FlutterMap` full-screen em tons de cinza, somente para exibição, com
  marcadores de origem/destino, geometria viária e enquadramento automático.
- Campo único de destino: a ação de busca do teclado consulta o Nominatim e
  seleciona automaticamente o primeiro resultado com coordenadas válidas.
- Origem obtida por captura pontual do GPS, com permissão iOS durante o uso,
  validação de precisão/idade e integração nativa cancelável por `MethodChannel`.
- Cálculo de rota `driving` pelo OSRM, incluindo distância e duração estimadas.
- Defaults públicos válidos para geocodificação, roteamento e tiles, com
  overrides opcionais por `GEOCODING_URL`, `ROUTING_URL`, `MAP_TILE_URL` e
  `MAPS_USER_AGENT`; o app inicia sem `dart-define`.
- Tiles OpenStreetMap diretos por default e atribuição simples não clicável
  `© OpenStreetMap contributors · ODbL`.
- Proteção contra respostas assíncronas antigas e apresentação de falhas de
  serviço no campo e de tiles em uma única `SnackBar`.
- Testes de startup/configuração, GPS e canal nativo, serviços de localização,
  estados assíncronos, responsividade, mapa e tratamento de erros.
- Pipeline para formatação, análise, testes com cobertura e build do iOS
  Simulator em pull requests e pushes para `main`.
- Documentação de contribuição e segurança e licença proprietária consistente
  com o arquivo `LICENSE`.
