# Fast Rider 🛵

Menor vertical slice Flutter do Rider: busca endereços, calcula uma rota viária
e exibe uma prévia OpenStreetMap antes de solicitar uma corrida ao backend
configurado. O app usa `StatefulWidget`/`setState` e não usa state management
ou repository pattern externo.

## Selecionar e solicitar

1. O mapa inicia em São Paulo, sem pontos pré-selecionados.
2. Digite rua, número e cidade em **A — Origem** e use **Buscar origem** (ou a
   ação de busca do teclado). Digitar não envia requisições: não há autocomplete.
3. Escolha explicitamente um resultado do Nominatim; repita para **B — Destino**.
   Nenhum resultado é selecionado automaticamente. Editar um endereço invalida
   sua seleção e a rota; respostas antigas não sobrescrevem entradas novas.
4. Com dois pontos distintos confirmados, o OSRM calcula uma rota `driving`.
   O mapa é **somente leitura**, sem toque para selecionar, arrasto, zoom ou
   rotação. Exibe marcadores A/B, a geometria viária e enquadramento automático.
   Distância e duração são estimativas. Falhas não viram uma linha reta:
   **Tentar rota novamente** permite nova tentativa manual.
5. **Solicitar corrida** só é habilitado com rota válida. Durante o envio,
   endereços e botão ficam bloqueados. O sucesso exibe o ID e mantém o bloqueio.
   **Nova solicitação** limpa a seleção sem enviar outra corrida automaticamente.
   Erros preservam a rota e mostram detalhes da API; não há retry automático.

O mapa usa `flutter_map`, tiles HTTPS de `tile.openstreetmap.org`, User-Agent
identificado como `fast_rider` e atribuição obrigatória e legível com link para
[© OpenStreetMap](https://www.openstreetmap.org/copyright).
O texto tem fundo opaco de alto contraste, suporta ampliação e o botão tem
altura mínima de 48 pontos lógicos. Se o navegador falhar, a URL da licença é
exibida na tela. Falhas de tiles exibem aviso sem remover marcadores, rota ou
atribuição.
Requer conexão. Não faz download offline/prefetch em massa; o cache padrão da
biblioteca é mantido. Para produção, revisar a
[política de tiles OSM](https://operations.osmfoundation.org/policies/tiles/)
e contratar um provedor adequado ao volume/SLA, se necessário.

### Busca, rota e privacidade

- Texto do endereço é enviado ao Nominatim **somente na busca explícita**;
  coordenadas confirmadas são enviadas ao OSRM para calcular a rota.
- Nominatim: fila compartilhada no isolate, intervalo mínimo de um segundo
  entre inícios, deduplicação de buscas pendentes e cache em memória de até
  100 consultas por dez minutos. HTTP 429/503 respeita `Retry-After` antes de
  futuras buscas (sem repetir automaticamente a requisição que falhou).
- Endpoints configuráveis via `--dart-define`: `GEOCODING_URL` (padrão
  `https://nominatim.openstreetmap.org/search`), `ROUTING_URL` (padrão
  `https://router.project-osrm.org`) e `MAPS_USER_AGENT` (identificação do app).
- Serviços públicos de demonstração, sem SLA. Antes de distribuir, revisar a
  [política Nominatim](https://operations.osmfoundation.org/policies/nominatim/),
  limites agregados entre usuários e identificação/contato do app; considerar
  proxy ou provedor contratado. Não enviar informações confidenciais.
- O POST de corrida permanece independente desses provedores: não inclui
  texto de endereços, geometria, distância ou duração, apenas as quatro coordenadas.

## Contrato HTTP

O app faz:

```http
POST {baseUrl}/api/v1/rides
Content-Type: application/json
rider_id: <UUID v4 do usuário dev>
```

Body:

```json
{
  "pickup_latitude": -23.55052,
  "pickup_longitude": -46.633308,
  "destination_latitude": -23.561684,
  "destination_longitude": -46.655981
}
```

O sucesso esperado é `201` com JSON contendo `id`, `rider_id`, as quatro
coordenadas e seus valores. Qualquer status `2xx` é aceito e parseado.

O app gera um UUID v4 aleatório na primeira instalação e o persiste em
`shared_preferences`. A mesma identidade é reutilizada em todas as
requisições; reinstalar o app gera uma nova identidade. O valor é enviado no
header `rider_id`, nunca no JSON body. Não há autenticação.

Erros HTTP preservam `error.code`, `error.message` e `error.requestId` (também
aceita `request_id`), além de `statusCode`. Timeout, conexão e resposta JSON
malformada recebem códigos locais (`timeout`, `connection_error` e
`malformed_response`).

## Plataformas suportadas

> **iOS apenas.** O target Android foi removido do projeto.

O desenvolvimento e a validação são feitos no **iOS Simulator**.

## Base URL e execução

`API_BASE_URL` é configurável por `--dart-define` e centralizado em
`lib/config/app_config.dart`:

- iOS Simulator: `http://localhost:8080` (default).

O backend deve estar acessível na rede do dispositivo e aceitar a porta 8080.

```bash
flutter pub get
open -a Simulator
flutter devices
flutter run -d <ios-simulator-id>
```

### Configuração local via `.env`

Copie o modelo e preencha os valores **sem commitar**:

```bash
cp .env.example .env
```

O projeto lê as chaves em tempo de compilação via `--dart-define-from-file`:

```bash
flutter run --dart-define-from-file=.env
flutter build ios --dart-define-from-file=.env
```

Chaves suportadas (todas opcionais, com defaults no `AppConfig`):

| Chave | Default | Uso |
|---|---|---|
| `API_BASE_URL` | `http://localhost:8080` | Backend de corridas |
| `GEOCODING_URL` | Nominatim público | Busca de endereços |
| `ROUTING_URL` | OSRM público | Cálculo de rota |
| `MAPS_USER_AGENT` | `fast_rider/1.0 ...` | Identificação OSM |
| `GEOCODING_ATTRIBUTION` | `Busca: Nominatim` | Atribuição no mapa |
| `ROUTING_ATTRIBUTION` | `Rota: OSRM` | Atribuição no mapa |

> **Importante:** valores compilados no app não são segredos reais — podem ser
> extraídos do binário. Use `.env` para **configuração** (URLs, user-agent).
> API keys/tokens devem viver no backend, nunca no cliente.

## Testes e qualidade

```bash
dart format .
flutter analyze
flutter test
```

As suítes (`address_flow`, `address_contract`, `location_services`,
`ride_api_client`, `ride_models`, `rider_identity`, `ride_map`) cobrem contrato
HTTP, parsing/erros, identidade, busca explícita/desambiguação, cache/limites,
rota e respostas tardias, envio duplicado, retry manual, sucesso e nova solicitação.
Incluem fluxo completo em tela 320×568 com texto 1×/2×, mapa read-only,
marcadores/polilinha, falhas de tiles e atribuição/licença.
Usam clientes falsos/mockados, tiles em memória e navegador simulado, sem
acessar os provedores ou criar corridas reais. Para cobertura: `flutter test --coverage`.

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para guia de desenvolvimento,
conventional commits e o fluxo com hooks locais ([lefthook](https://lefthook.dev)).

## Limitações

- Não há GPS, navegação turn-by-turn ou rota específica para moto: o perfil
  OSRM `driving` é uma prévia para carro. Busca e rota dependem da rede;
  identidade dev é persistida em `shared_preferences`, sem autenticação.
- O bloqueio de duplicatas é local à tela. O contrato atual não fornece chave
  de idempotência: após timeout/conexão perdida/resposta inválida, uma corrida
  pode ter sido criada. Confira no backend antes de repetir a solicitação.
- HTTP sem TLS é apenas para o slice local; produção deve usar HTTPS e
  configuração de segurança adequada.

## Licença

MIT — veja [LICENSE](LICENSE).