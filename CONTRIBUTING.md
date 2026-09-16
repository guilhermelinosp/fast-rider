# Contribuindo

Obrigado por contribuir com o Fast Rider! 🛵

## Fluxo de trabalho

1. Crie uma branch a partir da `main`: `feat/NOME` ou `fix/NOME`.
2. Implemente a mudança com commits convencionais.
3. Rode os checks locais (veja abaixo).
4. Abra um PR contra `main` usando o template.

## Conventional Commits

Formatos aceitos (usados também pelo Dependabot):

- `feat: nova funcionalidade`
- `fix: correção de bug`
- `refactor: mudança estrutural sem mudar comportamento`
- `style: formatação, lint, whitespace`
- `test: adicionar/corrigir testes`
- `chore: build, CI, dependências, tooling`
- `docs: documentação`

Escopo opcional: `feat(ride): ...`, `fix(api): ...`.

## Hooks locais (lefthook)

Os hooks rodam automaticamente:

- **pre-commit**: `dart format` (check) + `flutter analyze`
- **pre-push**: `flutter test`

Instalação (uma vez):

```bash
brew install lefthook
lefthook install
```

Se precisar pular em emergência (não recomendado):

```bash
lefthook run --force pre-commit
```

## Checks manuais

```bash
dart format .
flutter analyze
flutter test
flutter build ios --simulator
```

O CI (`/.github/workflows/ci.yml`) roda os mesmos checks mais o build iOS no
macOS, então um PR precisa passar nele antes do merge.

## Plataforma

O app é **iOS-only**. Não adicione código específico de Android, Gradle ou
Kotlin. Suporte a novas plataformas deve ser discutido em issue antes.

## Testes

- Cada área em `lib/` deve ter testes em `test/`.
- Testes não podem acessar rede real: use fakes, mocks e tiles em memória.
- Rode a suíte completa antes de abrir PR: `flutter test`.

## Dependências

- Atualizações são gerenciadas pelo Dependabot (semanal).
- Confira `flutter pub outdated` antes de abrir PRs de dependência.
- `pubspec.lock` **deve** ser commitado (app, não biblioteca).

## Código de conduta

Seja respeitoso. Discussões técnicas são bem-vindas; ataques pessoais não.