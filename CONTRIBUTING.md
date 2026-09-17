# Contribuindo

Obrigado por contribuir com o Fast Rider! 🛵

Este é um projeto proprietário. Uma contribuição não concede direitos de uso,
cópia ou distribuição além dos previstos em [LICENSE](LICENSE).

## Fluxo de trabalho

1. Crie uma branch a partir de `main`, com prefixo `feat/` ou `fix/`.
2. Implemente uma mudança focada e adicione ou atualize os testes relevantes.
3. Rode os checks locais descritos abaixo.
4. Abra um PR contra `main` usando o
   [template do projeto](.github/PULL_REQUEST_TEMPLATE/pull_request_template.md).
5. Aguarde o [pipeline](.github/workflows/pipeline.yml) passar antes do merge.

Vulnerabilidades não devem ser discutidas em PR ou issue pública. Siga a
[política de segurança](SECURITY.md).

## Ambiente local

O app tem target iOS. Instale Flutter stable, Xcode e um runtime do iOS
Simulator, depois execute:

```bash
flutter pub get
flutter run
```

O app inicia com os defaults de `AppConfig`; `.env` e `dart-define` não são
obrigatórios. Para testar endpoints compatíveis alternativos:

```bash
cp .env.example .env
flutter run --dart-define-from-file=.env
```

As únicas chaves aceitas atualmente são `GEOCODING_URL`, `ROUTING_URL`,
`MAP_TILE_URL` e `MAPS_USER_AGENT`. Elas são configurações públicas compiladas
no app, não um mecanismo para proteger segredos. Não adicione tokens ou
credenciais ao cliente nem versione o arquivo `.env`.

No iOS Simulator, configure uma posição em **Features > Location** e conceda a
permissão durante o uso para exercitar o fluxo real de GPS.

## Checks manuais

Execute os mesmos checks do CI:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter build ios --simulator --no-codesign
```

O workflow [`.github/workflows/pipeline.yml`](.github/workflows/pipeline.yml)
roda em pull requests e pushes para `main`. Ele não injeta configurações porque
os defaults do app são válidos.

## Testes

- Toda mudança de comportamento em `lib/` deve ter cobertura em `test/`.
- Testes não devem acessar GPS, rede ou tiles reais: use as interfaces, fakes,
  clientes HTTP simulados e providers em memória existentes.
- Preserve cobertura de startup/`AppConfig`, permissão e GPS pontual,
  `MethodChannel` iOS, respostas assíncronas antigas, responsividade e erros
  mostrados no campo ou em `SnackBar`.
- Para código nativo iOS, atualize também `ios/RunnerTests/` e valide o XCTest em
  um Simulator disponível.
- Não torne `.env` obrigatório e não dependa de provedores públicos nos testes.

## Hooks locais (lefthook)

Os hooks configurados em `lefthook.yml` executam:

- **pre-commit**: verificação de formato dos Dart staged files e
  `flutter analyze`;
- **pre-push**: `flutter test`.

Instalação opcional:

```bash
brew install lefthook
lefthook install
```

Os hooks ajudam, mas não substituem a suíte completa nem o pipeline.

## Conventional Commits

Use mensagens objetivas:

- `feat: nova funcionalidade`
- `fix: correção de bug`
- `refactor: mudança estrutural sem alterar comportamento`
- `style: formatação ou lint`
- `test: adicionar ou corrigir testes`
- `docs: documentação`
- `chore: build, CI, dependências ou tooling`

Um escopo opcional pode ser usado, por exemplo `fix(location): ...`.

## Dependências e plataforma

- O projeto é iOS-only; suporte a outra plataforma deve ser discutido antes.
- Atualizações de dependências são gerenciadas pelo Dependabot.
- `pubspec.lock` deve permanecer versionado, pois este repositório contém um
  aplicativo.
- Mudanças de provedor devem preservar identificação, atribuição e políticas de
  uso descritas no [README](README.md).

## Código de conduta

Seja respeitoso. Discussões técnicas são bem-vindas; ataques pessoais não.
