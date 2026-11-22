# План разработки бэкенда «Путь»

Источники: ТЗ в Notion («Тестовое задание. Практическая часть») и описания разделов
и стикеры «Для разработки» в Figma. Дата: 2026-11-22.

## 1. Что требует ТЗ (жёсткие условия сдачи)

| Требование | Что это значит для бэкенда |
|---|---|
| Аналог BlaBlaCar для маршруток малых городов | Пассажир бронирует место, водитель подтверждает |
| СМС не подключаем, код везде `111111` | `POST /auth/verify` принимает только `111111`, отправки СМС нет |
| Отзывы: функционала оставления нет, но в БД заложить | Таблица `reviews` + расчёт рейтинга; нет отзывов → «5 звёзд, нет отзывов» |
| Оплату не подключаем | «Оплатить» сразу переводит бронь в `paid`; платёж-заглушка |
| Проверка вне РФ, «сервера должны работать» | Публичный HTTPS-хостинг (не РФ), APK смотрит на него; плюс `docker compose up` для локального запуска |
| Сдача: APK + архив кода | Seed-данные, README с одной командой запуска |

## 2. Доменные правила из Figma

**Онбординг/авторизация**
- Выбор города/населённого пункта из списка доступных перед началом работы.
- Регистрация по телефону → код → заполнение имени и фото (аватар).
- Пользователь сам выбирает раздел: Водитель или Пассажир (одна учётка, две роли).

**Водитель: автомобили** — список прикреплённых к аккаунту авто (марка/модель, фото,
госномер, тип: легковой/автобус, мест). Фото лица водителя проходит проверку у администратора.

**Водитель: создание поездки**
- Пункт отправления, прибытия, промежуточные остановки.
- Дата/время, **кратно 30 минутам**.
- Количество мест для пассажиров.
- Цены: весь маршрут; **между любыми двумя остановками** (A→B, A→C, …, D→E;
  чем короче отрезок, тем выше цена за км — это задаёт водитель);
  **минимальная стоимость «за посадку»**.
- Комиссия сервиса добавляется сверху: водитель ставит 1000 → пассажир видит 1100 (10 %).
- Выбор авто из «Мои автомобили».
- Доп. услуги с ценой: детское кресло, животные, багаж, посылка.
- Посылки без пассажира: размеры S/M/L (макс. габариты/вес), можно отправить посылку без поездки.
- Режим бронирования: **стандартный** (водитель подтверждает/отклоняет заявку, затем
  пассажир оплачивает) или **быстрый** (сразу оплата, без подтверждения).
- Сохранить черновик, редактировать, создать **обратную** поездку (маршрут зеркально, новое время).
- Лимиты публикации: 1 поездка в сутки + 1 в обратном направлении; публикация не более чем на 3 дня вперёд.

**Пассажир: поиск**
- Список поездок; вкладки «Автомобили / Автобусы».
- Ранжирование: по рейтингу водителя (выше — выше), затем по времени отправления.
- Если на одном маршруте в одно время несколько машин — бронировать можно только
  первую (приоритетную); следующая открывается после заполнения первой.
  Обе показываются, но у неактивной нет зелёной плашки «идёт регистрация».
- Карточка: откуда, куда, дата/время, тип авто. Детали: остановки, места, цены общая и
  между остановками, минимальная, авто (марка/модель/фото), доп. услуги, водитель (имя,
  фото, рейтинг).
- Присоединиться: место в машине или только посылка.
- Фильтры: по названию населённого пункта (начало/конец), по геолокации («поблизости»).
- Монетизация: до брони видна общая сумма; при запросе оплаты — сумма комиссии к оплате;
  после оплаты — общая сумма, комиссия и сумма к оплате водителю.

**Пассажир: мои поездки** — брони с деталями, статусы, отмена, чат с водителем
(только по незавершённым). Отмена после регистрации → предупреждение «о нарушении
правил сообщества»; **2 отмены за 30 дней → блокировка на 30 дней** (видна администратору).

**Водитель: мои поездки** — активные/завершённые; список заявок, переход в профиль
пассажира (имя, фото, рейтинг); подтвердить/отклонить; изменить число свободных мест;
редактировать и удалять **только пока никто не присоединился**; отмена после брони —
те же правила блокировки, что у пассажира.

**Профиль** — имя, фамилия, фото (редактирование); рейтинг = f(кол-во поездок, кол-во
отмен); список полученных жалоб; выход.

## 3. Архитектура

Оставляем текущий стек: FastAPI + SQLAlchemy 2 async + Alembic + PostgreSQL (SQLite для
быстрых тестов). Структура `app/` расширяется по фичам:

```
app/
  api/routes/   auth, users, cities, cars, trips, search, bookings, notifications, media, admin
  services/     auth, pricing, availability, booking_flow, rating, sanctions
  models/  schemas/  core/ (config, security, errors)  db/
```

- Аутентификация: JWT access (15 мин) + refresh (30 дней), `Authorization: Bearer`.
- Деньги — `Numeric(10,2)` / целые копейки, комиссия в `settings` (`PUT_COMMISSION_PERCENT=10`).
- Время — `timestamptz`, UTC в БД, клиент присылает ISO-8601 с зоной.
- Файлы (аватары, фото авто): локальный том `/media` + раздача статикой; интерфейс
  хранилища, чтобы позже заменить на S3.
- Ошибки — единый формат `{"code": "...", "message": "..."}`, коды на английском,
  тексты на русском (клиенту удобно показывать как есть).
- Уведомления: таблица `notifications` + опрос клиентом (`GET /notifications`).
  Push (FCM) — опционально, если останется время.

## 4. Модель данных

| Таблица | Ключевые поля |
|---|---|
| `cities` | id, name, region, lat, lng, is_active |
| `users` | id, phone (unique), first_name, last_name, avatar_url, city_id, face_photo_status (none/pending/approved/rejected), blocked_until, is_admin, created_at |
| `auth_codes` / `refresh_tokens` | phone, code, expires_at, attempts / token_hash, user_id, expires_at, revoked |
| `car_brands` / `car_models` | справочник для выбора «Марка» → «Модель» (seed в миграции) |
| `cars` | id, owner_id, model_id, vehicle_type (car/bus), seats (легковой ≤ 8, автобус ≤ 60), plate (необязателен), photo_path, deleted_at — по экрану «Добавление нового ТС» |
| `trips` | id, driver_id, car_id, status (draft/published/cancelled; «completed» вычисляется: через 6 ч после отправления), departure_at, seats_total, booking_mode (manual/instant), full_price, min_price (целые рубли, без комиссии), return_of_trip_id, published_at, cancelled_at |
| `trip_stops` | id, trip_id, position, city_id, address, lat, lng |
| `trip_segment_prices` | trip_id, from_position, to_position, price — соседние пары обязательны (при 3+ остановках), другие пары — необязательные переопределения |
| `trip_extras` | trip_id, kind (child_seat/pets/luggage), price |
| `trip_parcel_prices` | trip_id, size (S/M/L), price; габариты/вес — константы (`GET /trips/parcel-sizes`); пусто — посылки не принимаются |
| `bookings` | id, trip_id, passenger_id, kind (seat/parcel), status, from_position, to_position, seats (0 у посылки), parcel_size, driver_price, commission, confirmed_at, paid_at, cancelled_at, cancelled_by (passenger/driver), created_at |
| `booking_extras` | booking_id, kind, price |
| `payments` | id, booking_id, amount (комиссия), status (paid), provider='mock', created_at |
| `reviews` | id, trip_id, booking_id, author_id, target_id, target_role, rating 1–5 (check), text, is_hidden (модерация), created_at, updated_at; unique trip+author+target. По ТЗ UI нет — API за флагом `PUT_REVIEWS_ENABLED` |
| `complaints` | id, author_id, target_id, trip_id, reason (no_show/late/rude/unsafe_driving/vehicle_mismatch/fraud/other), text, status (new/in_review/resolved/rejected), resolved_at, created_at |
| `cancellations` | id, user_id, role, trip_id, booking_id, blocked_until, created_at — только отмены-нарушения (после регистрации пассажира); основа санкций и рейтинга |
| `notifications` | id, user_id, type, title, body, payload JSON (trip_id, booking_id), read_at, created_at |
| `chats` | id, trip_id, driver_id, passenger_id (unique trip+passenger), last_message_at, driver_read_id, passenger_read_id |
| `chat_messages` | id (растущий, курсор и отметка прочтения), chat_id, sender_id, text ≤ 2000, created_at |

Статусы брони:
`pending` (ждёт водителя) → `awaiting_payment` → `paid` → `completed` (вычисляется);
боковые: `rejected`, `cancelled` + `cancelled_by` (passenger/driver). `pending` уже держит места.
Быстрое бронирование: сразу `awaiting_payment`.

## 5. API v1 (черновик)

```
POST  /auth/request-code        {phone}                → 204 (код всегда 111111)
POST  /auth/verify              {phone, code}          → {access, refresh, is_new_user}
POST  /auth/refresh             {refresh}              → {access, refresh}
POST  /auth/logout
GET   /cities?query=
GET   /me   PATCH /me           имя, фамилия, город
POST  /me/avatar   POST /me/face-photo   (multipart)
GET   /users/{id}               публичный профиль: имя, фото, рейтинг, кол-во отзывов
GET   /users/{id}/reviews   GET /me/complaints

GET   /cars/brands?query=   GET /cars/brands/{id}/models?query=
GET/POST /cars   GET/PATCH/DELETE /cars/{id}   PUT /cars/{id}/photo

GET   /trips/parcel-sizes
POST  /trips                    создать: {…, publish: false|true}
GET   /trips/mine?status=active|completed|draft|cancelled
GET   /trips/{id}               детали; цены как driver_price / commission / passenger_price
PUT   /trips/{id}               заменить целиком; только без активных броней
PATCH /trips/{id}/seats         число мест — можно и после броней
POST  /trips/{id}/publish   DELETE /trips/{id}
GET   /trips/{id}/cancel-preview   POST /trips/{id}/cancel → {trip, sanction}
POST  /trips/{id}/reverse       {departure_at, publish} → обратная поездка
GET   /trips/{id}/bookings      заявки для водителя

GET   /search/trips?from_city_id=&to_city_id=&from_query=&to_query=&lat=&lng=&radius_km=
                    &date=&vehicle_type=car|bus&seats=&limit=&offset=
      → {items: [карточка с board/alight-остановками пассажира, ценой его отрезка,
         driver{rating, reviews_count}, is_registration_open], total}
GET   /trips/{id}/price?from_position=&to_position=   цена и свободные места отрезка

POST  /bookings/quote           расчёт до бронирования
POST  /bookings                 {trip_id, from_position, to_position, kind, seats, extras[], parcel_size}
                                → цена с разбивкой (driver_price, commission, total)
GET   /bookings/mine?status=
POST  /bookings/{id}/confirm | /reject      (водитель)
POST  /bookings/{id}/pay        mock → сразу paid
GET   /bookings/{id}/cancel-preview   POST /bookings/{id}/cancel → {booking, sanction}

POST  /chats {booking_id}   GET /chats   GET /chats/unread-count   GET /chats/{id}
GET   /chats/{id}/messages?after_id=&before_id=&limit=   POST /chats/{id}/messages   POST /chats/{id}/read
WS    /chats/ws?token=   live: message / read / pong; клиент может слать message / read / ping
GET   /notifications?unread_only=   GET /notifications/unread-count
POST  /notifications/{id}/read   POST /notifications/read-all
POST  /complaints   POST /reviews (выключено флагом)
```

## 6. Ключевая бизнес-логика (сервисы + юнит-тесты)

1. **Цена** (`pricing`): цена отрезка from→to = заданная водителем цена сегмента
   (или сумма соседних, если пары нет), не ниже `min_price`; + доп. услуги / посылка;
   комиссия = round(price × 10 %); total = price + commission.
2. **Свободные места по отрезкам** (`availability`): место занято только на тех сегментах,
   которые пересекает бронь; свободно = seats_total − max занятых на пересекаемых сегментах.
   Считается в транзакции с `SELECT … FOR UPDATE` по поездке, чтобы не продать место дважды.
3. **Очередь машин** (`search`): поездки группируются по (маршрут, departure_at);
   внутри группы сортировка по приоритету водителя; `is_registration_open = true`
   только у первой незаполненной.
4. **Ранжирование**: `priority_rating` водителя DESC, затем `departure_at` ASC.
5. **Рейтинг** (`rating`): отображаемый = среднее по `reviews`, нет отзывов → 5.0 и
   `reviews_count = 0`; приоритетный для ранжирования = f(завершённые поездки, отмены).
6. **Санкции** (`sanctions`): отмена после регистрации пишет `cancellations` и
   возвращает предупреждение; 2 отмены за 30 дней → `blocked_until = now + 30d`;
   заблокированный не может бронировать/публиковать (403 `user_blocked`).
7. **Валидация поездки**: время кратно 30 мин и в будущем; не дальше 3 дней;
   лимит 1 прямая + 1 обратная в сутки; авто принадлежит водителю; мест ≤ мест авто.
8. **Редактирование**: запрещено при наличии броней `pending/awaiting_payment/paid`
   (кроме изменения числа мест не ниже занятого).
9. **Завершение поездок**: фоновая задача/ленивая проверка переводит прошедшие поездки
   в `completed`, брони — в `completed`.

## 7. Этапы

Статус: этапы 0–7 выполнены (2026-11-23).

| # | Этап | Результат | Оценка |
|---|---|---|---|
| 0 | Каркас | `services/`, единые ошибки, настройки (комиссия, лимиты), фикстуры pytest на Postgres/SQLite, CI-скрипт `ruff`+`pytest` | 0,5 дня |
| 1 | Авторизация и профиль | auth (111111, JWT, refresh), `/me`, загрузка аватара, `/cities` + seed городов | 1 день |
| 2 | Автомобили | CRUD авто + фото, тип car/bus | 0,5 дня |
| 3 | Создание поездки | trips + stops + цены сегментов + extras + посылки; валидации и лимиты; черновик/публикация/обратная/редактирование/удаление | 1,5 дня |
| 4 | Поиск | фильтры город/текст/гео/дата/тип, ранжирование, очередь машин, детали поездки с ценами и доступностью | 1 день |
| 5 | Бронирование и оплата | расчёт цены, места по отрезкам, ручной/быстрый режим, confirm/reject, mock-оплата, мои брони/поездки, уведомления | 1,5 дня |
| 6 | Отмены, рейтинг, отзывы, жалобы | санкции 2/30, рейтинг, таблицы reviews/complaints, «5 звёзд, нет отзывов» | 1 день |
| 7 | Чат | водитель ↔ пассажир по брони, история в БД, доставка по WebSocket, отметки прочтения | 0,5–1 день |
| 8 | Админка (минимум) | sqladmin: пользователи, блокировки, проверка фото лица, жалобы | 0,5 дня |
| 9 | Деплой и сдача | Docker-образ, Postgres, HTTPS-хостинг вне РФ, seed демо-водителей/поездок, README, проверка APK против прода | 1 день |

Итого ≈ 9–10 рабочих дней. Порядок совпадает с экранами клиента, так что мобильная
часть может подключаться к API этап за этапом. После этапа 1 фиксируем OpenAPI-контракт
(`/openapi.json`) и генерируем/сверяем модели в Flutter.

## 8. Открытые вопросы

1. **Хостинг**: Render / Fly.io / Railway / свой VPS? Нужен стабильный URL на время проверки.
2. **Чат** упомянут в описании и в нижнем меню, но отдельного раздела в Figma нет — делать
   или ставить заглушку?
3. **Push-уведомления** нужны или достаточно опроса и бейджей внутри приложения?
4. **Автобусы**: отличаются ли чем-то кроме вкладки в поиске и вместимости?
5. **Лимиты публикации**: в описании «N в сутки / X в неделю», на стикере «1 + 1 обратная,
   не дальше 3 дней» — берём стикер и выносим числа в настройки?
6. **Админка**: достаточно sqladmin, или проверку фото/блокировки показывать иначе?
