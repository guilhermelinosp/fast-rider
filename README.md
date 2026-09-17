# Fast Rider 🛵

[![CI](https://github.com/guilhermelinosp/fast-rider/actions/workflows/pipeline.yml/badge.svg)](https://github.com/guilhermelinosp/fast-rider/actions/workflows/pipeline.yml)
[![Design no Figma](https://img.shields.io/badge/Design-Figma-purple)](https://www.figma.com/design/5C9coBRcFFtoxZVjVGsyt2/Fast-Rider?m=auto&fuid=1190329279918509245)

Fast Rider é uma prévia mínima de rota para iOS. A tela tem um mapa
`FlutterMap` em tons de cinza ocupando todo o espaço e um único `TextField`
flutuante na parte inferior para o destino. A localização pontual do aparelho
define a origem; ao enviar o destino pelo teclado, o app busca o primeiro
resultado válido e desenha a rota viária calculada pelo OSRM.

A versão 1.0.0 termina na visualização da rota: não envia pedidos nem mantém
conta ou identidade persistente no aparelho.

## Como funciona

1. Ao abrir, o app solicita permissão de localização durante o uso e faz uma
   captura pontual do GPS. A origem centraliza o mapa e recebe o marcador **A**.
2. Digite rua, número e cidade em **Destino**. Digitar não dispara rede nem
   autocomplete; pressione **Enter/Buscar** para iniciar a busca no Nominatim.
3. O primeiro resultado com coordenadas válidas é selecionado automaticamente
   e recebe o marcador **B**. Não existe uma etapa de escolha manual.
4. Com origem e destino válidos e diferentes, o app consulta uma rota OSRM no
   perfil `driving`, desenha sua geometria e mostra distância e duração
   estimadas.
5. A câmera enquadra automaticamente origem, destino e rota. O mapa é somente
   para exibição: toque, seleção, arrasto, zoom e rotação estão desabilitados.

Se a primeira captura de localização falhar, o próximo envio pelo teclado faz
uma nova tentativa pontual. Respostas assíncronas antigas de GPS, geocodificação
ou rota são descartadas quando deixam de corresponder ao estado atual. Erros de
serviço aparecem no campo; falhas de tiles geram uma única `SnackBar` sem
remover os marcadores ou a rota.

## Arquitetura

O slice mantém estado local com `StatefulWidget`/`setState` e interfaces pequenas
para permitir testes sem rede ou sensores reais:

- `lib/main.dart`: valida `AppConfig` e monta o app.
- `lib/pages/ride_page.dart`: coordena GPS, destino, rota e estados assíncronos.
- `lib/location/current_location.dart`: captura pontual, valida precisão e idade
  da posição e usa um `MethodChannel` cancelável no iOS.
- `lib/api/location_services.dart`: clientes compatíveis com Nominatim e OSRM.
- `lib/widgets/ride_map.dart`: mapa em tons de cinza, marcadores, polilinha,
  enquadramento automático e atribuição.

## Plataformas

O projeto oferece target **iOS** e é desenvolvido e validado no iOS Simulator.
O bundle ID do app é `com.guilhermelino.fastrider`.

Pré-requisitos:

- Flutter stable compatível com o SDK Dart declarado em `pubspec.yaml`;
- Xcode com um runtime do iOS Simulator instalado;
- conexão de rede para geocodificação, rota e tiles.

## Executar sem configuração

Os provedores públicos têm defaults válidos. Nenhum `dart-define` ou arquivo
`.env` é necessário para iniciar:

```bash
flutter pub get
flutter run
```

No Simulator, escolha uma localização em **Features > Location**, conceda a
permissão durante o uso quando solicitada e, se houver mais de um device:

```bash
open -a Simulator
flutter devices
flutter run -d <device-id>
```

Para apenas validar o build do Simulator:

```bash
flutter build ios --simulator --no-codesign
```

## Overrides opcionais

`lib/config/app_config.dart` centraliza quatro overrides opcionais de
compilação. Para usá-los, copie o exemplo e altere somente o necessário:

```bash
cp .env.example .env
flutter run --dart-define-from-file=.env
```

| Nome | Default | Uso |
|---|---|---|
| `GEOCODING_URL` | `https://nominatim.openstreetmap.org/search` | Endpoint `/search` compatível com Nominatim |
| `ROUTING_URL` | `https://router.project-osrm.org` | Endpoint compatível com OSRM |
| `MAP_TILE_URL` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Template de tiles raster; exige `{z}`, `{x}` e `{y}` |
| `MAPS_USER_AGENT` | `com.guilhermelino.fastrider/1.0.0` | Identificação HTTP usada na geocodificação e na rota |

O package name usado por `flutter_map` no User-Agent dos tiles é fixo em
`com.guilhermelino.fastrider`; ele não é uma chave de configuração. Overrides
malformados falham cedo na validação, mas valores omitidos usam os defaults.

Essas URLs e identificadores são configuração pública, não segredos. Valores
compilados podem ser extraídos do app; não coloque tokens, credenciais ou outras
informações sigilosas em `.env` ou em `dart-define`.

## Provedores, atribuição e limites

- Os tiles vêm diretamente de `tile.openstreetmap.org` por default.
  `MAP_TILE_URL` permite trocar por um provedor raster compatível.
- A atribuição sempre visível é texto simples e não clicável:
  `© OpenStreetMap contributors · ODbL`.
- O servidor público de tiles deve ser usado de acordo com a
  [Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).
  Ele não é uma solução para alto tráfego, garantia de disponibilidade ou SLA;
  distribuições com volume relevante devem usar infraestrutura própria ou um
  provedor apropriado.
- O Nominatim público também exige respeito à
  [Usage Policy](https://operations.osmfoundation.org/policies/nominatim/).
  O cliente serializa inícios de busca com intervalo mínimo de um segundo,
  deduplica consultas pendentes e mantém no máximo 100 resultados em memória
  por dez minutos. Não há repetição automática da requisição que falhou.
- O endpoint público do OSRM é adequado somente para demonstração e não oferece
  SLA. A rota `driving` é uma estimativa para carro, não navegação turn-by-turn
  nem uma rota específica para motocicleta.

## Privacidade

- O iOS recebe apenas a descrição de uso `when-in-use`. Cada tentativa pede uma
  posição atual; não há stream, localização em segundo plano, posição conhecida
  anterior nem rastreamento contínuo.
- O texto do destino é enviado ao serviço de geocodificação somente após
  **Enter/Buscar**.
- As coordenadas de origem e destino são enviadas ao serviço de roteamento.
- Requisições de tiles revelam ao provedor os tiles visualizados e metadados de
  rede usuais, como endereço IP e User-Agent.
- Resultados e rota permanecem apenas em memória durante a execução. O app não
  faz geocodificação reversa nem persiste histórico de localização ou destino.

Antes de trocar endpoints, revise a política de privacidade e os termos do novo
provedor. Não digite informações confidenciais no campo de destino.

## Testes e qualidade

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter build ios --simulator --no-codesign
```

A suíte atual cobre:

- startup e `AppConfig` com defaults, sem `dart-define`, além de overrides
  inválidos;
- permissão/GPS pontual, validação de precisão e idade, timeout, cancelamento e
  o `MethodChannel` iOS;
- busca explícita, seleção do primeiro resultado válido, rota e descarte de
  respostas assíncronas antigas;
- mapa sem interação, atribuição, erro de tiles e `SnackBar`;
- layouts compactos, landscape, teclado, safe areas e ampliação de texto.

Os testes Dart usam fakes, clientes HTTP simulados e tiles em memória; não
acessam provedores públicos. A validação da versão 1.0.0 concluiu com
`flutter analyze` sem issues, 83/83 testes Dart, 1/1 XCTest nativo e build do
iOS Simulator.

## Contribuindo e segurança

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para o fluxo de desenvolvimento e
[SECURITY.md](SECURITY.md) para reportar vulnerabilidades de forma privada.

## Licença

**Proprietária — todos os direitos reservados.** O projeto não é open source;
uso, cópia, modificação ou distribuição exigem autorização prévia e por escrito.
Veja [LICENSE](LICENSE).

## Design

O design de interface está disponível no
[Figma](https://www.figma.com/design/5C9coBRcFFtoxZVjVGsyt2/Fast-Rider?m=auto&fuid=1190329279918509245).
