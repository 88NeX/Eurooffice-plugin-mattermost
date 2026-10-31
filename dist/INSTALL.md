# Установка EuroOffice + плагина для Mattermost

Пошаговая инструкция «с нуля»: сервер EuroOffice DocumentServer → установка
плагина → настройка → проверка → бот → сквозной тест.

Проверено на Mattermost 12.0.1 и EuroOffice DocumentServer 9.3.7-1
(образ `ghcr.io/euro-office/documentserver:latest`).

---

## 0. Схема и требования

```
Браузер ──► Mattermost (:8065) ◄── плагин 88nex.eurooffice
                  │                        │
                  │  файлы в каналах        │ HTTP + JWT
                  ▼                        ▼
             filestore            EuroOffice DocumentServer (:80/443)
```

Что нужно:

| Компонент | Требования |
|---|---|
| Mattermost | ≥ 9.11.0, linux-amd64, включены плагины |
| EuroOffice | 2 vCPU, 2–4 GB RAM, 20+ GB диска, Docker |
| Сеть | Mattermost видит DocServer; DocServer видит Mattermost по `SiteURL`; браузеры видят оба |
| Порты | 80/443 DocServer, 8065 Mattermost (или ваш reverse proxy) |

Важно: `SiteURL` в Mattermost должен быть адресом, доступным **с DocServer**
(иначе callback сохранения не дойдёт).

---

## 1. Подготовка сервера EuroOffice

```bash
# каталоги для логов и данных (лог-подкаталоги обязательны)
sudo mkdir -p /opt/euro-office/logs/{converter,metrics,docservice,adminpanel}
sudo mkdir -p /opt/euro-office/data

# JWT-секрет: не короче 32 символов
openssl rand -hex 32
```

Полученную строку сохраните — она понадобится и в DocServer, и в плагине.

---

## 2. Запуск EuroOffice DocumentServer

### Вариант A: docker run

```bash
docker run -d --name euro-office --restart unless-stopped \
  -p 80:80 \
  -e JWT_ENABLED=true \
  -e JWT_SECRET='<ВАШ_JWT_СЕКРЕТ>' \
  -e JWT_HEADER=AuthorizationJwt \
  -v /opt/euro-office/logs:/var/log/euro-office/documentserver \
  -v /opt/euro-office/data:/var/www/euro-office/documentserver/Data \
  ghcr.io/euro-office/documentserver:latest
```

Почему `JWT_HEADER=AuthorizationJwt`: Mattermost-прокси не пропускает
стандартный `Authorization`, поэтому используется отдельный заголовок.
Префикс по умолчанию — `Bearer `.

### Вариант B: docker compose

```yaml
services:
  euro-office:
    image: ghcr.io/euro-office/documentserver:latest
    container_name: euro-office
    restart: unless-stopped
    ports:
      - "80:80"
    environment:
      JWT_ENABLED: "true"
      JWT_SECRET: "${EO_JWT_SECRET}"
      JWT_HEADER: "AuthorizationJwt"
    volumes:
      - ./logs:/var/log/euro-office/documentserver
      - ./data:/var/www/euro-office/documentserver/Data
```

```bash
EO_JWT_SECRET='<секрет>' docker compose up -d
```

---

## 3. Проверка DocServer

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<DOCSERVER>/healthcheck
# 200
curl -s -o /dev/null -w '%{http_code}\n' http://<DOCSERVER>/web-apps/apps/api/documents/api.js
# 200
```

Если `healthcheck` не 200 — смотрите `docker logs euro-office`; чаще всего
это отсутствующие каталоги логов или слабый JWT-секрет (<32 символов).

---

## 4. Установка плагина в Mattermost

Файл: `eurooffice-1.0.0.tar.gz` (рядом с этим документом).

### System Console

1. Войдите системным администратором.
2. **System Console → Plugins → Plugin Management**.
3. Убедитесь, что включены `Enable Plugins` и `Enable Plugin Uploads`.
4. **Upload Plugin** → выберите `eurooffice-1.0.0.tar.gz`.
5. Включите плагин (Enable).

### mmctl (альтернатива)

```bash
mmctl plugin add eurooffice-1.0.0.tar.gz
mmctl plugin enable 88nex.eurooffice
```

Плагин не подписан: если на сервере включён `RequirePluginSignature`,
загрузка будет отклонена — отключите проверку подписи или подпишите бандл.

---

## 5. Настройка плагина

**System Console → Plugins → EuroOffice**:

| Поле | Значение |
|---|---|
| EuroOffice Docs address | `http://<DOCSERVER>/` (со слэшем на конце) |
| Document Server JWT Secret | тот же секрет, что в `JWT_SECRET` |
| JWT Header | `AuthorizationJwt` (как `JWT_HEADER`) |
| JWT Prefix | `Bearer ` |
| Allow private Document Server address | **Да**, если DocServer в LAN/приватной сети |

Поле секрета после сохранения отображается пустым/звёздочками — это
штатно, значение сохранено.

Технически настройки лежат в `PluginSettings.Plugins.88nex.eurooffice`
в нижнем регистре (`desaddress`, `desjwt`, `desjwtheader`, `desjwtprefix`,
`desallowprivate`). Вручную через API:

```bash
curl -X PUT http://<MM>/api/v4/config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @config.json
```

---

## 6. Проверка плагина и редактора

```bash
curl -s http://<MM>/plugins/88nex.eurooffice/api/health
# {"healthy":true,...}
```

Проверка editor-страницы для конкретного файла (id файла Mattermost):

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $USER_TOKEN" \
  "http://<MM>/plugins/88nex.eurooffice/api/editor?file=<FILE_ID>"
# 200, HTML с api.js вашего DocServer
```

---

## 7. Бот

При активации плагин сам создаёт бота `eurooffice`
(Display Name: **EuroOffice**, аватар — `assets/logo.png`) и использует его
для уведомлений об изменениях документов в тредах сообщений.

Проверка:

```bash
mmctl bot list
# eurooffice(Owned by 88nex.eurooffice, Enabled)
```

Если бота нет:

1. Проверьте, что плагин включён и активен (`/api/health` → healthy).
2. Перезапустите плагин: Disable → Enable в System Console.
3. Проверьте логи: `docker logs <mattermost> | grep eurooffice`.

Бот не требует ручной настройки и не является отдельным сервисом.

---

## 8. Сквозной тест

1. Отправьте `.docx` в канал.
2. Меню файла (⋮) → **Open in EuroOffice**.
3. Должен открыться редактор; изменения сохраняются в файл Mattermost.
4. Пригласите второго пользователя — проверьте совместное редактирование и
   уведомления от бота в треде.

Если редактор пустой — проверьте, что браузер открывает `http://<DOCSERVER>`
напрямую и что `Allow private` включён.

---

## 9. Опционально: Nextcloud

Если нужен ещё и Nextcloud:

1. Установите приложение **ONLYOFFICE** (app `onlyoffice`) в Nextcloud.
2. В настройках приложения укажите тот же `http://<DOCSERVER>/` и JWT-секрет.
3. Проверьте: открытие документа из Nextcloud.

DocServer один и тот же, конфликта с плагином нет.

---

## 10. Обновление и откат

### DocServer

```bash
docker pull ghcr.io/euro-office/documentserver:latest
# сохранить JWT/WOPI env, остановить старый контейнер, запустить новый
# с теми же портами/томами; старый контейнер оставить до проверки
```

### Плагин

1. Загрузите новый `eurooffice-*.tar.gz` (Upload Plugin с overwrite).
2. Настройки сохраняются, повторно вводить секрет не нужно.
3. Проверьте `/api/health` и editor.

### Откат

- Плагин: удалить и загрузить предыдущий бандл.
- DocServer: вернуть прежний контейнер/образ (JWT-секрет должен совпадать).

---

## 11. Диагностика

| Симптом | Причина / решение |
|---|---|
| Плагин не активируется: «No valid credentials» | не заданы адрес/JWT |
| `401` от DocServer | секрет или `JWT Header` не совпадают |
| `403` при открытии файла | нет прав на файл/пост |
| Редактор пустой | DocServer не виден из браузера |
| Ошибка «private address» | включите `Allow private` |
| Сохранение не работает | DocServer не видит Mattermost `SiteURL` |
| `healthcheck` не 200 | нет каталогов логов / слабый JWT-секрет |
| `command not found` | плагин не включён/не активен |

Логи:

```bash
docker logs euro-office --tail=100
docker logs <mattermost> 2>&1 | grep -i eurooffice
```

---

## 12. Безопасность и лицензии

- Плагин: Apache-2.0 (`LICENSE`, `NOTICE`, `AUTHORS.md` в бандле),
  неофициальная интеграция.
- EuroOffice DocumentServer: AGPL-3.0 — отдельная программа, в плагин не
  входит; при распространении модифицированного DocServer действуют
  требования AGPL.
- JWT-секрет и токены храните в менеджере секретов; в Mattermost
  secret-поля маскируются, но в конфиге БД лежат открыто.
- Плагин неподписанный; Mattermost выполняет плагины без песочницы —
  устанавливайте только доверенные бандлы.
- Для публичного доступа — TLS (reverse proxy) и HSTS; не выставляйте
  DocServer в интернет без аутентификации.
