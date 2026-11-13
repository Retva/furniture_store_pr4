# Контракт учебного API «МебельДом»

Базовый адрес: `http://localhost:8080/api`. Формат — JSON в UTF-8.

## Общие соглашения

### Список

`GET /api/<коллекция>` возвращает страницу:

```json
{ "items": [ ... ], "page": 1, "size": 10, "total": 41, "totalPages": 5 }
```

Общие параметры:

| Параметр | Значение |
| --- | --- |
| `page` | номер страницы, с 1 |
| `size` | размер страницы, 1–100, по умолчанию 10 |
| `sort` | `поле,asc` или `поле,desc` |
| `search` | подстрока без учёта регистра |
| `includeDeleted` | `true` — вместе с логически удалёнными |

### Ошибки

| Код | Когда | Тело |
| --- | --- | --- |
| 400 | тело не является JSON | `{ "message": "..." }` |
| 401 | нет токена или он истёк | `{ "message": "..." }` |
| 403 | роль не позволяет | `{ "message": "..." }` |
| 404 | записи или адреса нет | `{ "message": "..." }` |
| 409 | действие противоречит данным | `{ "message": "..." }` |
| 422 | данные не прошли проверку | `{ "message": "Ошибка валидации", "errors": { "поле": "текст" } }` |
| 500 | ошибка сервера | `{ "message": "..." }` |

### Учебные параметры

Любой запрос: `?__delay=1500` — ответ через 1,5 с; `?__fail=500` — ответ с этим кодом.

## Аутентификация

`POST /api/auth/login` `{ "username", "password" }` → `{ accessToken, refreshToken, expiresIn, user }`.
`POST /api/auth/refresh`, `GET /api/auth/me`, `POST /api/auth/logout`.

Изменения требуют заголовка `Authorization: Bearer <accessToken>`.

## Ресурсы

Для `products`, `manufacturers`, `categories`, `materials`, `customers` одинаковый набор:

| Метод и адрес | Роль | Ответ |
| --- | --- | --- |
| `GET /api/products` | — | страница |
| `GET /api/products/{id}` | — | запись или 404 |
| `POST /api/products` | manager | 201 + запись, 422 |
| `PUT /api/products/{id}` | manager | 200 + запись, 404, 422 |
| `DELETE /api/products/{id}` | manager | 204, 404, 409 |
| `DELETE /api/products/{id}?hard=true` | admin | 204, 404, 409 |
| `POST /api/products/{id}/restore` | admin | 200 + запись |
| `POST /api/products/bulk-delete` `{ "ids": [..] }` | manager | `{ "deleted": n }`, 409 |

Фильтры списков:

| Коллекция | Фильтры | Сортировка |
| --- | --- | --- |
| products | `categoryId`, `manufacturerId`, `materialId`, `priceFrom`, `priceTo`, `inStock` | name, sku, price, stock |
| manufacturers | `country` | name, country, foundedYear |
| categories | — | name |
| materials | `kind` | name, kind, origin |
| customers | `card=yes|no` | fullName, email, discount |

### Товар: запись и чтение

На запись передаются идентификаторы связей:

```json
{ "name": "Диван «Осло»", "sku": "DV-1001", "manufacturerId": 2,
  "categoryIds": [1], "materialIds": [4, 9], "price": 54990, "stock": 3,
  "widthCm": 210, "depthCm": 95, "heightCm": 85, "color": "серый", "description": "" }
```

В ответе связи развёрнуты:

```json
{ "id": 1, "name": "Диван «Осло»", "sku": "DV-1001",
  "manufacturer": { "id": 2, "name": "Северный лес" },
  "categories": [ { "id": 1, "name": "Диваны" } ],
  "materials": [ { "id": 4, "name": "Массив бука" } ],
  "price": 54990, "stock": 3, "...": "...", "createdAt": "...", "deletedAt": null }
```

Производитель так же: на запись `materialIds`, в ответе `materials: [{id, name}]`.
Покупатель: `card: { number, discountPercent, issuedAt }` или `null`; на сервере карта
хранится отдельной записью (один к одному).

### Проверки (422)

- товар: артикул `AA-0000` и уникален; производитель, категории, материалы существуют;
  материалы — из тех, с которыми работает производитель; цена > 0; остаток ≥ 0; размеры 1–500;
- производитель: уникальное название, год 1800–текущий, корректная почта;
- категория, материал: уникальное название; тип материала из списка;
- покупатель: уникальная почта; номер карты — 8 цифр и уникален; скидка 1–30; дата не в будущем.

### Конфликты (409)

- удаление производителя, категории, материала, на которые ссылаются товары;
- удаление товара или покупателя с незакрытыми заказами;
- заказ на количество больше остатка.

## Заказы

| Метод и адрес | Роль | Ответ |
| --- | --- | --- |
| `GET /api/orders?productId=&customerId=` | — | страница |
| `POST /api/orders` `{ customerId, productId, quantity }` | manager | 201, 409, 422 |
| `POST /api/orders/{id}/cancel` | manager | 200, 409 (уже отменён) |

Сервер списывает товар со склада и считает сумму со скидкой по карте покупателя.

## CORS

Сервер отвечает на каждый запрос заголовками

```
Access-Control-Allow-Origin: http://localhost:5555
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

и на предварительный запрос `OPTIONS` — кодом 204.
