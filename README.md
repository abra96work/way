# Путь

Мобильный сервис совместных междугородних поездок. Монорепозиторий содержит:

- `mobile/` — Flutter-клиент для Android, iOS и Web;
- `backend/` — REST API на FastAPI;
- `compose.yaml` — PostgreSQL и backend для локальной разработки.

## Проектная память «Грабли»

Перед работой прочитайте [`docs/ГРАБЛИ.md`](docs/ГРАБЛИ.md). При ошибке сначала
найдите её точный текст в журнале; подтверждённые неочевидные и повторяемые
решения фиксируются там же по протоколу из `.agents/skills/grabli/SKILL.md`.

## Быстрый старт

### Backend без Docker (SQLite)

```powershell
cd backend
uv sync --dev
Copy-Item .env.example .env
uv run alembic upgrade head
uv run fastapi dev app/main.py
```

API будет доступен на `http://127.0.0.1:8000`, документация — на
`http://127.0.0.1:8000/docs`.

Схемой БД владеет Alembic: после изменения моделей добавляйте миграцию в
`backend/alembic/versions/`. Первая миграция пользователей заполняет список городов.

#### Авторизация (тестовый режим)

СМС не подключены, код подтверждения всегда `111111`.

1. `POST /api/v1/auth/request-code` `{"phone": "+79001234567"}`
2. `POST /api/v1/auth/verify` `{"phone": "+79001234567", "code": "111111"}` → `access_token`,
   `refresh_token`, `is_new_user`, `user`
3. Запросы с заголовком `Authorization: Bearer <access_token>`; access живёт 15 минут,
   новую пару выдаёт `POST /api/v1/auth/refresh` (старый refresh после этого недействителен).
4. Новый пользователь заполняет `PATCH /api/v1/me` (`first_name`, `last_name`, `city_id`)
   и `PUT /api/v1/me/avatar` (multipart, поле `file`).

#### Чат водителя и пассажира

Чат открывается по брони: `POST /api/v1/chats {"booking_id": ...}` (тот же чат для обоих).
История и отправка — REST (`/chats/{id}/messages`), доставка в реальном времени —
WebSocket `ws://<host>/api/v1/chats/ws?token=<access_token>`: сервер присылает
`{"type": "message", ...}` и `{"type": "read", ...}`, клиент может отправлять
`{"type": "message", "chat_id", "text"}`, `{"type": "read", "chat_id"}`, `{"type": "ping"}`.
Соединения хранятся в памяти процесса — API запускается одним воркером (так и сделано в Docker).

Ошибки приходят в едином формате `{"code": "...", "message": "..."}`: `code` — для логики
клиента, `message` — готовый русский текст. Ссылки на файлы (`avatar_url`) относительны
хосту API, например `/media/avatars/<id>.jpg`.

### Backend с PostgreSQL

```powershell
Copy-Item .env.example .env
docker compose up --build
```

### Flutter

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Для Android Emulator используется `10.0.2.2`; для Chrome и iOS Simulator —
`http://127.0.0.1:8000`. Для физического телефона укажите локальный IP компьютера.

## Проверки

```powershell
cd backend
uv run ruff check .
uv run pytest

cd ../mobile
flutter analyze
flutter test
```
