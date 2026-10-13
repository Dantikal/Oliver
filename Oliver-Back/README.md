# Oliver Backend

Backend маркетплейса из `Oliver-Task.txt`: REST API `/api/v1`, WebSocket/STOMP `/ws`, PostgreSQL, Redis, S3, SMTP. Java 17+, Maven 3.9+, Spring Boot 3.5.16. Все перечисленные в ТЗ маршруты реализованы.

## Запуск всего стека

Нужен запущенный Docker Engine / Docker Desktop. Создайте `.env` из примера и задайте случайный JWT-секрет.

```sh
cp -n .env.example .env
# Замените JWT_SECRET в .env случайным секретом, например выводом openssl rand -hex 32.
docker compose up --build -d
```

| Сервис | Адрес |
| --- | --- |
| REST API | http://localhost:8080/api/v1 |
| Swagger UI | http://localhost:8080/swagger-ui.html |
| OpenAPI JSON | http://localhost:8080/v3/api-docs |
| Health | http://localhost:8080/actuator/health |
| Mailpit — письма с кодами и сбросом пароля | http://localhost:8025 |
| MinIO Console | http://localhost:9001 |

Compose автоматически создаёт БД, применяет Flyway-миграции, создаёт бакет `oliver` и разрешает публичное чтение загруженных файлов. MinIO Console использует `S3_ACCESS_KEY` / `S3_SECRET_KEY` из `.env`. Данные PostgreSQL, Redis и MinIO сохраняются в volumes.

```sh
docker compose logs -f api
docker compose down
```

Для мобильного клиента замените `S3_PUBLIC_URL` на адрес, доступный телефону: например `http://192.168.1.20:9000/oliver`. REST API на телефоне также должен использовать IP компьютера. Ссылки сохраняются в БД при загрузке: изменение переменной не переписывает существующие URL.

## Запуск Java без контейнера приложения

```sh
docker compose up -d postgres redis minio minio-init mailpit
export JWT_SECRET="$(openssl rand -hex 32)"
mvn spring-boot:run
```

Переменные в `.env` автоматически читает Docker Compose; для Maven/`java -jar` экспортируйте нужные переменные в окружение процесса. Полный набор параметров находится в `src/main/resources/application.yml`: PostgreSQL (`DATABASE_*`), Redis (`REDIS_*`), SMTP (`SMTP_*`, `MAIL_FROM`), S3 (`S3_*`), CORS (`ALLOWED_ORIGINS`, список через запятую), ссылка восстановления (`RESET_URL`), порт (`PORT`).

```sh
mvn verify
java -jar target/oliver-backend-1.0.0.jar
```

## Авторизация

1. `POST /auth/register`: `phone` в формате `+996XXXXXXXXX`, `email`, `fullName`, `password`, `confirmPassword`. Пароль: 8–72 символа и не более 72 байт UTF-8 (ограничение BCrypt).
2. `POST /auth/login`: email + пароль. Ответ содержит `requires2fa: true` и `sessionId`.
3. Получите шестизначный код из письма. В локальном окружении письма видны в Mailpit.
4. `POST /auth/verify-2fa`: `sessionId` + `code`. Ответ: `accessToken`, `refreshToken`, профиль.
5. Передавайте `Authorization: Bearer <accessToken>` в защищённые REST-запросы.

Код действует 5 минут, разрешено 5 попыток проверки. Повторная отправка: не чаще раза в 60 секунд, до 5 повторов. Access token действует 15 минут. Refresh token действует 30 дней и заменяется при каждом `/auth/refresh`; повторное использование старого токена запрещено. В Redis хранятся хэши кодов и refresh/reset-токенов.

`/auth/logout` отзывает переданный refresh token; уже выпущенный access token действует до истечения срока. Сброс пароля повышает `token_version`, немедленно запрещая прежние access/refresh-токены и 2FA-сессии. Запрос восстановления возвращает одинаковый текст для существующего и неизвестного email. Reset token одноразовый, срок — 15 минут; письмо содержит `RESET_URL?token=...`.

Регистрация всегда создаёт `USER`. Администратора назначают оператором БД:

```sql
UPDATE users SET role = 'ADMIN', token_version = token_version + 1
WHERE email = 'admin@example.com';
```

После этого пользователь входит заново. `ADMIN` может редактировать и удалять чужие товары и удалять комментарии. Доступ к чужим личным чатам администраторам не предоставляется.

## Контракт для клиента

Исходное ТЗ: [Oliver-Task.txt](Oliver-Task.txt). Снимок схемы для генерации клиента: [docs/openapi.json](docs/openapi.json); живой `/v3/api-docs` отражает текущий код.

- Идентификаторы пользователей, товаров, файлов, комментариев, чатов, сообщений и уведомлений — UUID. Категории, регионы и города — числовые ID из справочников.
- Пагинация: `page` с нуля, `size` от 1 до 100; по умолчанию 20. Ответы со списками товаров, сообщений, комментариев и уведомлений содержат `items`, `total`, `page`, `size`.
- Сортировка товаров: `createdAt,desc` (по умолчанию), `createdAt,asc`, `price,asc`, `price,desc`. Поиск без учёта регистра по названию и описанию. Родительская категория включает товары вложенных категорий.
- Валюты: `KGS`, `USD`, `EUR`, `RUB`, `KZT`. Цены хранятся как decimal, без пересчёта валют; для сопоставимого диапазона цен передавайте `currency`.
- Город обязан принадлежать выбранной области. Стартовые миграции содержат 9 регионов, основные города и базовое дерево категорий; справочники можно расширять следующими миграциями.
- Даты возвращаются в ISO 8601 UTC. Ошибки REST: `{ timestamp, status, error, message, path }`.
- PATCH меняет переданные ненулевые поля. Для очистки `whatsappLink` / `telegramLink` передайте пустую строку. Остальные обязательные поля нельзя очистить. При передаче `media` список заменяется; `[]` удаляет связи с медиа.
- Добавление избранного и лайка комментария идемпотентно. Лайк товара в этом контракте — добавление товара в избранное; отдельного маршрута лайка товара в ТЗ нет. Владелец получает `PRODUCT_LIKE`, если лайк поставил другой пользователь. `newLikes` — непрочитанные такие уведомления.
- Комментарии: страница корневых комментариев с `replies`; разрешён один уровень ответов. `total` считает корневые комментарии. Удаление корневого комментария удаляет его ответы и лайки.
- Для пары пользователей создаётся один чат. `productId` задаёт контекст при первом создании и должен принадлежать собеседнику. Повторный запрос с этой парой возвращает существующий чат. Сообщения возвращаются от новых к старым.

### Загрузка файлов

Multipart-поле — `file`. JPEG, PNG, WebP до 50 MB, MP4 до 50 MB; аватар — изображение до 5 MB. Тип определяется по сигнатуре содержимого, имя файла и заявленный MIME не используются для выбора типа. В одном товаре не больше 20 файлов.

```sh
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F file=@photo.jpg http://localhost:8080/api/v1/media/upload
```

Ответ: `{ mediaId, url, type, size }`. Сначала загрузите файлы через `/media/upload`, затем создайте товар с `media: [{ "mediaId": "UUID" }]`. Нельзя прикрепить чужой файл или файл, уже прикреплённый к другому товару. Альтернатива — загрузка непосредственно в существующий товар через `/products/{id}/media`. `/users/me/avatar` сразу меняет аватар; PATCH профиля принимает URL ранее загруженного вашим пользователем изображения.

Типы сообщений: `TEXT`, `IMAGE`, `VIDEO`. Для TEXT нужен непустой `content`, без `mediaUrl`. Для IMAGE/VIDEO передавайте `content` (можно `""`) и `mediaUrl` файла соответствующего типа, загруженного отправителем. Загрузка медиа чата использует общий `/media/upload`.

### WebSocket / STOMP

Нативный WebSocket без SockJS: `ws://localhost:8080/ws` (в production — `wss`). Передайте STOMP CONNECT header `Authorization: Bearer <accessToken>`; токен в URL не поддерживается. Для браузера origin должен входить в `ALLOWED_ORIGINS`.

```js
// Пример с @stomp/stompjs
const client = new Client({
  brokerURL: 'ws://localhost:8080/ws',
  connectHeaders: { Authorization: `Bearer ${accessToken}` },
  onConnect: () => {
    client.subscribe(`/topic/chats/${chatId}`, frame => {
      const event = JSON.parse(frame.body);
      console.log(event);
    });
    client.publish({
      destination: `/app/chats/${chatId}/send`,
      body: JSON.stringify({ type: 'TEXT', content: 'Здравствуйте!' })
    });
  }
});
client.activate();
```

Подписка разрешена только участникам чата. Прямые SEND в `/topic/**` запрещены. Токен повторно проверяется при SEND/SUBSCRIBE; после его истечения получите новый токен и переподключитесь.

| Destination для SEND | Тело | Событие подписчикам |
| --- | --- | --- |
| `/app/chats/{chatId}/send` | `{type, content, mediaUrl?}` | `{type:"MESSAGE", message:{...}}` |
| `/app/chats/{chatId}/read` | `{}` | `{type:"READ", userId}` |
| `/app/chats/{chatId}/typing` | `{}` | `{type:"TYPING", userId}` |

REST-отправка и отметка прочтения публикуют те же события. Событие MESSAGE отправляется после успешного коммита БД. Redis Pub/Sub раздаёт события всем экземплярам API, каждый обслуживает свои WebSocket-соединения. Pub/Sub не хранит историю: при переподключении догружайте сообщения через REST. READ помечает все входящие сообщения чата прочитанными; сообщение своего автора не увеличивает его счётчик.

## Архитектура и проверка

```text
api/          REST/STOMP controllers, request/response DTO, обработка ошибок
service/      бизнес-логика товаров, комментариев, чатов, файлов и писем
auth/         JWT/2FA/refresh/reset, интерфейс временного хранилища, Redis
repository/   JDBC repository, параметризованные SQL-запросы
config/       security, CORS, OpenAPI, WebSocket, Redis Pub/Sub, S3
resources/db/migration/  Flyway: схема, ограничения, индексы, справочники
```

Изменения данных выполняются транзакционно. Права проверяются в сервисах. Для конкурентного создания чата и идемпотентных лайков используются ограничения БД и блокировки строк; порядок блокировок пользователей фиксирован. Refresh и 2FA потребляются атомарно в Redis. HTTP rate limiting: 180 API-запросов / минуту на IP, отдельный лимит auth — 30 / минуту; WebSocket — 120 SEND/SUBSCRIBE / минуту на пользователя. Лимиты общие для экземпляров API. По умолчанию IP берётся из сетевого соединения, входящему `X-Forwarded-For` сервис не доверяет.

```sh
mvn test
```

7 интеграционных сценариев поднимают полный Spring-контекст, применяют настоящие Flyway-миграции к H2 в PostgreSQL-режиме и проверяют REST через MockMvc: 2FA/TTL/лимит попыток, ротацию/logout/reset, поиск по дереву категорий, товары/избранное/уведомления, ответы/лайки комментариев, чат/счётчики/права доступа, WebSocket CONNECT/SUBSCRIBE/SEND-права, загрузку медиа/владение, ADMIN, валидацию и OpenAPI. Redis, SMTP и S3 в этом наборе заменены тестовыми реализациями/моками. Тесты не требуют Docker. Они генерируют `target/openapi.json`.

Полный запуск с реальными PostgreSQL, Redis, SMTP, S3 и сетевым WebSocket проверяется отдельно через Compose: автоматические тесты на H2 не заменяют эту проверку.

## Развёртывание

Compose предназначен для локальной разработки. Для рабочего окружения задайте отдельные секреты и подключения к сервисам, SMTP с TLS и авторизацией, HTTPS/WSS, реальные `ALLOWED_ORIGINS`, `RESET_URL` и `S3_PUBLIC_URL`. Используйте один JWT_SECRET и общие PostgreSQL/Redis/S3 для всех экземпляров. Redis содержит действующие refresh/reset/2FA-сессии: используйте persistence и запрет вытеснения этих ключей. Для S3 настройте lifecycle удалённых/неприкреплённых файлов: удаление товара удаляет записи и связи в БД, но не физические объекты. Если Pub/Sub недоступен после коммита сообщения, сообщение остаётся доступно через REST; доставка события журналируется как ошибка.
