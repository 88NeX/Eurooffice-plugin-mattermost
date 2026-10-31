# Безопасность плагина EuroOffice

Аудит от 31.10.2026: анализ исходников, бинарника, зависимостей и модели
авторизации. Это не формальный пентест.

## Что проверено

- **Исходники Go/TS:** нет `os/exec`, `syscall`, `unsafe`,
  `InsecureSkipVerify`, `eval`, `new Function`, `dangerouslySetInnerHTML`,
  `document.write`, обфускации.
- **Сеть:** исходящие запросы только к `DESAddress` (DocumentServer) и к
  Mattermost API. Внешних C2/телеметрии в коде нет. Строки
  `169.254.169.254`, `amazonaws.com`, `login.microsoftonline.com` в
  бинарнике — код зависимостей Mattermost `server/v8` (filestore), плагин
  их не вызывает.
- **Авторизация:** `/api/callback` и `/api/download` проверяют JWT
  (подпись `DESJwt`); `/editor`, `/create`, `/convert`, `/permissions`,
  `/mentions/*` — сессия Mattermost или короткоживущий код из KV;
  `/image` — одноразовый код; `/health` и `/config` публичны, но не
  содержат секретов.
- **SSRF:** адрес DocumentServer задаётся админом; приватные адреса
  разрешены только при `DESAllowPrivate=true` (нужно для LAN).
- **Секреты:** JWT-секрет помечен `secret: true` — маскируется в UI и API
  (`********************************`). В конфиге Mattermost хранится в открытом
  виде (так устроен Mattermost), доступ к БД/конфигу нужно ограничивать.

## Зависимости

`govulncheck` после обновлений:

| Модуль | Advisory |
|---|---|
| `github.com/mattermost/mattermost/server/v8` | 68 |
| `golang.org/x/net` | 0 (было 5) |
| `google.golang.org/grpc` | 0 (было 1) |

Обновлены: `x/net v0.62.0`, `grpc v1.85.0`, `server/v8` на pseudoversion
от 30.10.2026. Оставшиеся 68 — старые advisory Mattermost 2024 года,
которые govulncheck не мапит на новый модуль (`Fixed in: N/A`); трассы
идут через `filestore.init` и HTTP-транспорт, а не через логику плагина.
Формально это зависимостный риск, а не эксплуатируемая уязвимость плагина.

`npm audit` (webapp): 37 замечаний, все в dev/build-обвязке
(1 low, 36 moderate), **0 critical/high** после `npm audit fix`.
В runtime-бандл dev-зависимости не попадают.

## Остаточные риски

1. Плагин **не подписан**; Mattermost выполняет плагины без песочницы с
   правами серверного API — устанавливать только из доверенного источника.
2. `server/v8` тянет большой плагинный бинарник (~48 MB) и cloud-SDK
   (AWS/Azure) ради filestore-интерфейсов; поверхность атаки шире, чем
   нужно плагину.
3. JWT-секрет и токен Grafana хранятся в конфиге Mattermost в открытом
   виде (маскировка — только отображение).

## Воспроизведение

```bash
# Go
docker run --rm -v $PWD:/src -w /src golang:1.26 sh -c \
  'go install golang.org/x/vuln/cmd/govulncheck@latest && \
   $(go env GOPATH)/bin/govulncheck ./...'

# Webapp
cd webapp && npm audit
```
