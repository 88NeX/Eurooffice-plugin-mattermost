# EuroOffice plugin for Mattermost

Плагин открывает и редактирует офисные документы из чатов Mattermost через
**EuroOffice DocumentServer** (форк ONLYOFFICE DocumentServer).

- ID: `88nex.eurooffice`
- Версия: `1.0.0` (ребренд ONLYOFFICE-плагина 2.4.1, Apache-2.0)
- Совместимость: Mattermost 9.11+, linux-amd64

## Что умеет

- Открывать файлы из сообщений в редакторе EuroOffice (Word/Excel/
  PowerPoint/PDF) — «Open in EuroOffice» в меню файла.
- Совместное редактирование в реальном времени.
- Создавать документы прямо в чате.
- Управлять правами (просмотр/редактирование), уведомления от бота.

## Требования

1. **EuroOffice DocumentServer** (например,
   `ghcr.io/euro-office/documentserver:latest`), доступный:
   - с сервера Mattermost (server-to-server),
   - из браузеров пользователей.
2. JWT включён на DocServer (`JWT_ENABLED=true`), известен секрет и header
   (по умолчанию `AuthorizationJwt`).
3. DocServer должен уметь обращаться к Mattermost (callback).

## Установка

1. **System Console → Plugins → Plugin Management**.
2. Включите плагины и загрузку.
3. **Upload Plugin** → `dist/eurooffice-1.0.0.tar.gz`.
4. Включите плагин.
5. **System Console → Plugins → EuroOffice**:
   - **EuroOffice Docs address** — `http://<docserver>:<port>/`
     (со слэшем на конце);
   - **Document Server JWT Secret** — секрет DocServer;
   - **JWT Header** — как в `JWT_HEADER` DocServer (обычно
     `AuthorizationJwt`);
   - **JWT Prefix** — обычно `Bearer `;
   - **Allow private Document Server address** — **Да**, если DocServer в
     приватной сети/LAN (иначе адрес будет отклонён).

> Поля JWT-секрета после сохранения отображаются пустыми — Mattermost не
> показывает secret-поля. Проверка: плагин должен активироваться без ошибки
> и `GET /plugins/88nex.eurooffice/api/health` вернуть
> `{"healthy":true}`.

## Проверка

1. Отправьте `.docx` в канал.
2. Меню файла → **Open in EuroOffice** — должен открыться редактор.
3. Или health:

```bash
curl http://<mattermost>/plugins/88nex.eurooffice/api/health
```

## Сборка из исходников

```bash
./build.sh
# результат: dist/eurooffice-1.0.0.tar.gz
```

Скрипт клонирует `ONLYOFFICE/onlyoffice-mattermost` (с сабмодулями),
переименовывает плагин в `88nex.eurooffice`, меняет брендинг,
собирает сервер (`golang:1.26`) и webapp (`node:24`) в Docker и пакует
бандл. Нужны Docker и git.

## Диагностика

| Симптом | Причина |
|---|---|
| «No valid credentials provided» при активации | не заданы адрес/JWT |
| `401` от DocServer | секрет/JWT header не совпадают |
| Редактор пустой | DocServer не виден из браузера |
| «private address» ошибка | включите Allow private |
| Health false | DocServer недоступен с сервера Mattermost |

## Ограничения

- Собрано только под linux-amd64.
- Ребрендинг косметический: внутренние имена/пути совместимы с ONLYOFFICE
  (это требуется для работы с форком).
- Версия зафиксирована на upstream 2.4.1; при обновлении upstream
  пересоберите через `build.sh`.

## Лицензия и происхождение

Плагин — производная от **ONLYOFFICE app for Mattermost**
(https://github.com/ONLYOFFICE/onlyoffice-mattermost), лицензия
**Apache License 2.0**. Наши изменения (ребрендинг, id, теги конфигурации,
иконка) распространяются на тех же условиях.

- `LICENSE` — текст Apache-2.0 (обязателен при распространении).
- `NOTICE` — атрибуция upstream и список изменений.
- `src/` — полный исходный код сборки (без node_modules и артефактов).

Публикация на GitHub допустима при соблюдении Apache-2.0: сохранить
`LICENSE`, уведомления об авторстве, отметить изменённые файлы, не
использовать товарные знаки как бренд проекта (см. §6 лицензии).

Важно: **EuroOffice DocumentServer** — отдельная программа под **AGPL-3.0**
(форк ONLYOFFICE DocumentServer). В этот плагин её код не входит, плагин
общается с ней по HTTP API. Если вы публикуете модифицированный
DocumentServer (образ/патчи), действуют требования AGPL-3.0, включая
предоставление исходников и §13 (сетевое использование).
## Безопасность

Аудит исходников, бинарника, зависимостей и авторизации — в
[SECURITY.md](SECURITY.md). Кратко: вредоносного кода не найдено; JWT
проверяется на callback/download; секрет маскируется в UI/API; Go- и
npm-зависимости обновлены (остались только старые advisory Mattermost
`server/v8`, не достижимые через логику плагина).

## Установка с нуля

Полная инструкция — [INSTALL.md](INSTALL.md): от развёртывания EuroOffice DocumentServer до плагина, бота и сквозного теста.
