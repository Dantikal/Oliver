# Oliver — Flutter frontend

Маркетплейс объявлений (RU / KY / EN, светлая/тёмная тема). Только фронт; backend делает отдельный разработчик.

## Запуск

```bash
flutter pub get
open -a Simulator
flutter run                     # mock-режим, сервер не нужен
```

Демо-вход в mock-режиме: любые email/пароль (поля уже заполнены), код 2FA — `123456`.

Реальный backend:

```bash
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://<host>:8080
```

## Архитектура

Clean Architecture, feature-first:

```
lib/
  core/         config, theme, network (Dio + JWT interceptor), storage, l10n,
                router (go_router), pagination, widgets (UI-кит), mock (in-memory backend)
  features/
    auth/       login, register, 2FA, forgot password
    catalog/    home (поиск, фильтры), product details, create/edit, comments
    favorites/
    chats/      список, комната, STOMP WebSocket + REST fallback
    notifications/  счётчики и лента активности
    profile/    мой профиль, чужой профиль, настройки
    shell/      нижняя навигация
```

Каждая фича: `domain/` (сущности + интерфейсы репозиториев), `data/` (Dio-реализация + mock-реализация + провайдер),
`presentation/` (Riverpod-контроллеры и экраны). Флаг `AppConfig.useMock` выбирает реализацию.

## Заметки для backend

- JWT передаётся как `Authorization: Bearer <token>`. При 401 клиент один раз вызывает `POST /auth/refresh`;
  если не вышло, выполняется авто-логаут и переход на экран входа.
- Пагинация: `page` с нуля, ответ `{ items, total, page, size }` (поддерживается и Spring-формат `content/totalElements/number`).
- Товар: клиент читает `category{id,name}` или `categoryId/categoryName`, аналогично для `region`/`city`.
  Желательно добавить `isFavorite`, `commentsCount`, `viewsCount`.
- Чаты: в `GET /chats` хорошо бы отдавать `peer.online` и `product{id,title,imageUrl}`.
- WebSocket: чистый WS на `/ws` (без SockJS), STOMP 1.2, `Authorization` в CONNECT-заголовке.
  Тело события: `{ "event": "MESSAGE"|"READ"|"TYPING"|"DELIVERED", "chatId", "message"?, "clientId"?, "userId"?, "typing"?, "messageId"? }`.
  `clientId` — id оптимистичного сообщения клиента; верните его в эхо MESSAGE.
  Typing клиент шлёт в `/app/chats/{chatId}/typing`.
- Активность: в уведомлениях клиент ожидает `type` (LIKE/COMMENT/MESSAGE/SYSTEM), `actorName`, `actorAvatarUrl`,
  `productId`, `productImageUrl`, `text`, `isRead`.
- Ошибки: `{ timestamp, status, error, message, path }`; `message` показывается пользователю.

## Push

FCM подключён (`firebase_messaging`), но выключен до появления конфигов:
добавьте `GoogleService-Info.plist` / `google-services.json` и запускайте с `--dart-define=ENABLE_PUSH=true`.
