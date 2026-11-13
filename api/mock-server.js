#!/usr/bin/env node
/**
 * Мок-сервер учебного API «МебельДом».
 *
 * Построен по образцу учебного сервера «Библиотека» и следует тем же
 * соглашениям (см. КОНТРАКТ-API.md): оболочка списка, формат ошибок,
 * коды 401/403/404/409/422, CORS, вход по логину и паролю, роли.
 * Зависимостей нет — нужен только Node.js 18 или новее.
 *
 *   node mock-server.js
 *   node mock-server.js --port 8080 --origin http://localhost:5555
 *
 * Данные хранятся в памяти и сбрасываются при перезапуске
 * либо запросом POST /api/__reset. Начальный набор — файл seed.json.
 *
 * Учебные возможности:
 *   ?__delay=1500   задержка ответа в миллисекундах
 *   ?__fail=500     принудительный код ошибки
 */

'use strict';

const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const pathLib = require('node:path');

// ─────────────────────────── параметры запуска ───────────────────────────

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', '*');
const SECRET = 'учебный-ключ-не-для-продакшена';
const ACCESS_TTL = Number(arg('ttl', 900));
const REFRESH_TTL = 60 * 60 * 24 * 7;
const SEED_FILE = pathLib.join(__dirname, 'seed.json');
// Необязательно: папка собранного приложения (flutter build web), которую
// сервер отдаёт на всех адресах, кроме /api. Тогда приложение и API
// работают с одного адреса и CORS не участвует.
const STATIC_DIR = arg('static', null);

// ─────────────────────────────── токены ───────────────────────────────

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

function sign(payload) {
  const withId = { ...payload, jti: crypto.randomUUID() };
  const body = b64url(JSON.stringify(withId));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return body + '.' + mac;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [body, mac] = token.split('.');
  const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (mac !== expected) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.exp && payload.exp * 1000 < Date.now()) return null;
  return payload;
}

// ─────────────────────────────── данные ───────────────────────────────

const COLLECTIONS = ['products', 'manufacturers', 'categories', 'materials', 'customers', 'orders'];
const MATERIAL_KINDS = ['Дерево', 'Плита', 'Ткань', 'Кожа', 'Металл', 'Стекло', 'Пластик'];

let db;

function seed() {
  const data = JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));
  const now = new Date().toISOString();
  db = { seq: {}, users: [], refreshTokens: new Set() };

  for (const name of ['products', 'manufacturers', 'categories', 'materials', 'customers']) {
    db[name] = (data[name] || []).map((row) => ({ ...row, createdAt: now, deletedAt: row.deletedAt || null }));
    db.seq[name] = db[name].reduce((max, row) => Math.max(max, row.id), 0);
  }

  // Дисконтная карта хранится отдельной таблицей со ссылкой на покупателя:
  // так на сервере выглядит связь «один к одному».
  db.cards = [];
  db.seq.cards = 0;
  for (const c of db.customers) {
    if (c.card) {
      db.cards.push({ id: ++db.seq.cards, customerId: c.id, ...c.card });
    }
    delete c.card;
  }

  db.orders = [];
  db.seq.orders = 0;

  pushUser('admin', 'admin123', 'Администратор', 'admin');
  pushUser('manager', 'manager123', 'Петрова А. С.', 'manager');
  pushUser('viewer', 'viewer123', 'Гость каталога', 'viewer');
}

function pushUser(username, password, fullName, role) {
  db.seq.users = (db.seq.users || 0) + 1;
  db.users.push({ id: db.seq.users, username, passwordHash: hash(password), fullName, role, deletedAt: null });
}

function push(collection, obj) {
  db.seq[collection] = (db.seq[collection] || 0) + 1;
  const id = db.seq[collection];
  const row = { id, ...obj, createdAt: new Date().toISOString(), deletedAt: null };
  db[collection].push(row);
  return row;
}

function hash(password) {
  return crypto.createHash('sha256').update(password + SECRET).digest('hex');
}

const byId = (collection, id) => db[collection].find((x) => x.id === Number(id));
const slim = (collection, id, field = 'name') => {
  const row = byId(collection, id);
  return row ? { id: row.id, [field]: row[field] } : null;
};

// ──────────────────────── развёртывание объектов ────────────────────────
// На чтение связи приходят объектами, на запись — идентификаторами.

function expandProduct(p) {
  return {
    id: p.id,
    name: p.name,
    sku: p.sku,
    manufacturer: slim('manufacturers', p.manufacturerId),
    categories: p.categoryIds.map((id) => slim('categories', id)).filter(Boolean),
    materials: p.materialIds.map((id) => slim('materials', id)).filter(Boolean),
    price: p.price,
    stock: p.stock,
    widthCm: p.widthCm,
    depthCm: p.depthCm,
    heightCm: p.heightCm,
    color: p.color,
    description: p.description,
    createdAt: p.createdAt,
    deletedAt: p.deletedAt,
  };
}

function expandManufacturer(m) {
  return {
    id: m.id,
    name: m.name,
    country: m.country,
    city: m.city,
    foundedYear: m.foundedYear,
    email: m.email,
    website: m.website,
    materials: m.materialIds.map((id) => slim('materials', id)).filter(Boolean),
    description: m.description,
    createdAt: m.createdAt,
    deletedAt: m.deletedAt,
  };
}

function cardOf(customerId) {
  return db.cards.find((c) => c.customerId === customerId) || null;
}

function expandCustomer(c) {
  const card = cardOf(c.id);
  return {
    id: c.id,
    fullName: c.fullName,
    email: c.email,
    phone: c.phone,
    card: card
      ? { id: card.id, number: card.number, discountPercent: card.discountPercent, issuedAt: card.issuedAt }
      : null,
    createdAt: c.createdAt,
    deletedAt: c.deletedAt,
  };
}

function expandOrder(o) {
  return {
    id: o.id,
    customer: slim('customers', o.customerId, 'fullName'),
    product: slim('products', o.productId),
    quantity: o.quantity,
    total: o.total,
    status: o.cancelledAt ? 'cancelled' : 'active',
    createdAt: o.createdAt,
    cancelledAt: o.cancelledAt || null,
    deletedAt: o.deletedAt,
  };
}

const EXPANDERS = {
  products: expandProduct,
  manufacturers: expandManufacturer,
  customers: expandCustomer,
  orders: expandOrder,
  categories: (c) => c,
  materials: (m) => m,
};

// ─────────────────────────── поиск, фильтры, сортировка ───────────────────────────

function searchableText(collection, x) {
  switch (collection) {
    case 'products': return [x.name, x.sku].join(' ');
    case 'manufacturers': return [x.name, x.country].join(' ');
    case 'categories': return [x.name, x.description].join(' ');
    case 'materials': return [x.name, x.origin].join(' ');
    case 'customers': return [x.fullName, x.email, x.phone].join(' ');
    default: return '';
  }
}

function applyFilters(collection, rows, q) {
  let result = rows;

  if (q.search) {
    const needle = String(q.search).toLowerCase();
    result = result.filter((x) => searchableText(collection, x).toLowerCase().includes(needle));
  }

  if (collection === 'products') {
    if (q.categoryId) result = result.filter((p) => p.categoryIds.includes(Number(q.categoryId)));
    if (q.materialId) result = result.filter((p) => p.materialIds.includes(Number(q.materialId)));
    if (q.manufacturerId) result = result.filter((p) => p.manufacturerId === Number(q.manufacturerId));
    if (q.priceFrom) result = result.filter((p) => p.price >= Number(q.priceFrom));
    if (q.priceTo) result = result.filter((p) => p.price <= Number(q.priceTo));
    if (q.inStock === 'true') result = result.filter((p) => p.stock > 0);
  }
  if (collection === 'manufacturers' && q.country) {
    result = result.filter((m) => m.country === q.country);
  }
  if (collection === 'materials' && q.kind) {
    result = result.filter((m) => m.kind === q.kind);
  }
  if (collection === 'customers' && q.card) {
    result = result.filter((c) => (q.card === 'yes') === Boolean(cardOf(c.id)));
  }
  if (collection === 'orders') {
    if (q.customerId) result = result.filter((o) => o.customerId === Number(q.customerId));
    if (q.productId) result = result.filter((o) => o.productId === Number(q.productId));
  }
  return result;
}

function sortValue(collection, row, field) {
  if (collection === 'customers' && field === 'discount') {
    const card = cardOf(row.id);
    return card ? card.discountPercent : -1;
  }
  return row[field];
}

function applySort(collection, rows, sort) {
  const [field, dirRaw] = String(sort || 'id,asc').split(',');
  const dir = (dirRaw || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const av = sortValue(collection, a, field);
    const bv = sortValue(collection, b, field);
    let r = 0;
    if (av == null && bv == null) r = 0;
    else if (av == null) r = 1;
    else if (bv == null) r = -1;
    else if (typeof av === 'number' && typeof bv === 'number') r = av - bv;
    else r = String(av).localeCompare(String(bv), 'ru', { sensitivity: 'base' });
    // При равных значениях порядок задаёт id, иначе записи «прыгают» между страницами.
    return (r || a.id - b.id) * dir;
  });
}

function paginate(rows, q) {
  const page = Math.max(1, Number(q.page) || 1);
  const size = Math.min(100, Math.max(1, Number(q.size) || 10));
  const total = rows.length;
  return {
    items: rows.slice((page - 1) * size, page * size),
    page,
    size,
    total,
    totalPages: Math.max(1, Math.ceil(total / size)),
  };
}

// ─────────────────────────────── валидация ───────────────────────────────

const str = (v) => (typeof v === 'string' ? v.trim() : '');
const isInt = (v) => Number.isInteger(Number(v)) && v !== '' && v !== null && v !== undefined;
const EMAIL = /^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zA-Z]{2,}$/;
const alive = (collection, id) => {
  const row = byId(collection, id);
  return row && !row.deletedAt ? row : null;
};
const duplicate = (collection, field, value, id) =>
  db[collection].some(
    (x) => x.id !== id && !x.deletedAt && String(x[field] || '').toLowerCase() === String(value).toLowerCase()
  );

function validate(collection, body, id = null) {
  const e = {};
  const year = new Date().getFullYear();

  if (collection === 'products') {
    if (!str(body.name)) e.name = 'Укажите название';
    else if (str(body.name).length > 100) e.name = 'Не длиннее 100 символов';

    if (!str(body.sku)) e.sku = 'Укажите артикул';
    else if (!/^[A-Za-z]{2}-\d{4}$/.test(str(body.sku))) e.sku = 'Формат: две латинские буквы, дефис, четыре цифры';
    else if (duplicate('products', 'sku', str(body.sku), id)) e.sku = `Артикул ${str(body.sku).toUpperCase()} уже есть у другого товара`;

    const manufacturer = alive('manufacturers', body.manufacturerId);
    if (!manufacturer) e.manufacturerId = 'Производитель не найден';

    const categoryIds = Array.isArray(body.categoryIds) ? body.categoryIds.map(Number) : [];
    if (!categoryIds.length) e.categoryIds = 'Выберите хотя бы одну категорию';
    else if (categoryIds.some((cid) => !alive('categories', cid))) e.categoryIds = 'Категория не найдена';

    const materialIds = Array.isArray(body.materialIds) ? body.materialIds.map(Number) : [];
    if (!materialIds.length) e.materialIds = 'Выберите хотя бы один материал';
    else if (materialIds.some((mid) => !alive('materials', mid))) e.materialIds = 'Материал не найден';
    else if (manufacturer && materialIds.some((mid) => !manufacturer.materialIds.includes(mid))) {
      e.materialIds = 'Производитель не работает с некоторыми из выбранных материалов';
    }

    if (!isInt(body.price) || Number(body.price) <= 0) e.price = 'Цена — целое число больше нуля';
    if (!isInt(body.stock) || Number(body.stock) < 0) e.stock = 'Остаток — целое число, не меньше нуля';
    for (const f of ['widthCm', 'depthCm', 'heightCm']) {
      if (!isInt(body[f]) || Number(body[f]) < 1 || Number(body[f]) > 500) e[f] = 'От 1 до 500 см';
    }
    if (!str(body.color)) e.color = 'Укажите цвет';
  }

  if (collection === 'manufacturers') {
    if (!str(body.name)) e.name = 'Укажите название';
    else if (duplicate('manufacturers', 'name', str(body.name), id)) e.name = 'Производитель с таким названием уже есть';
    if (!str(body.country)) e.country = 'Укажите страну';
    if (!str(body.city)) e.city = 'Укажите город';
    if (!isInt(body.foundedYear) || Number(body.foundedYear) < 1800 || Number(body.foundedYear) > year) {
      e.foundedYear = `Год от 1800 до ${year}`;
    }
    if (!str(body.email)) e.email = 'Укажите почту';
    else if (!EMAIL.test(str(body.email))) e.email = 'Некорректный адрес почты';
    const materialIds = Array.isArray(body.materialIds) ? body.materialIds.map(Number) : [];
    if (!materialIds.length) e.materialIds = 'Выберите хотя бы один материал';
    else if (materialIds.some((mid) => !alive('materials', mid))) e.materialIds = 'Материал не найден';
  }

  if (collection === 'categories') {
    if (!str(body.name)) e.name = 'Укажите название';
    else if (duplicate('categories', 'name', str(body.name), id)) e.name = 'Такая категория уже есть';
  }

  if (collection === 'materials') {
    if (!str(body.name)) e.name = 'Укажите название';
    else if (duplicate('materials', 'name', str(body.name), id)) e.name = 'Такой материал уже есть';
    if (!MATERIAL_KINDS.includes(str(body.kind))) e.kind = 'Выберите тип из списка';
    if (!str(body.origin)) e.origin = 'Укажите страну происхождения';
  }

  if (collection === 'customers') {
    if (!str(body.fullName)) e.fullName = 'Укажите ФИО';
    if (!str(body.email)) e.email = 'Укажите почту';
    else if (!EMAIL.test(str(body.email))) e.email = 'Некорректный адрес почты';
    else if (duplicate('customers', 'email', str(body.email), id)) e.email = 'Покупатель с такой почтой уже есть';
    if (!str(body.phone)) e.phone = 'Укажите телефон';

    const card = body.card;
    if (card) {
      const number = str(card.number);
      if (!/^\d{8}$/.test(number)) e.cardNumber = 'Номер карты — ровно 8 цифр';
      else if (db.cards.some((c) => c.number === number && c.customerId !== id)) e.cardNumber = 'Карта с таким номером уже выдана';
      if (!isInt(card.discountPercent) || Number(card.discountPercent) < 1 || Number(card.discountPercent) > 30) {
        e.discountPercent = 'Скидка от 1 до 30 %';
      }
      const issued = new Date(card.issuedAt);
      if (Number.isNaN(issued.getTime())) e.issuedAt = 'Некорректная дата выдачи';
      else if (issued > new Date()) e.issuedAt = 'Дата не может быть в будущем';
    }
  }

  return e;
}

function normalize(collection, body) {
  const num = (v) => (v == null || v === '' ? null : Number(v));
  const ids = (v) => (Array.isArray(v) ? [...new Set(v.map(Number).filter((n) => Number.isInteger(n)))] : []);

  switch (collection) {
    case 'products':
      return {
        name: str(body.name),
        sku: str(body.sku).toUpperCase(),
        manufacturerId: num(body.manufacturerId),
        categoryIds: ids(body.categoryIds),
        materialIds: ids(body.materialIds),
        price: num(body.price),
        stock: num(body.stock) ?? 0,
        widthCm: num(body.widthCm),
        depthCm: num(body.depthCm),
        heightCm: num(body.heightCm),
        color: str(body.color),
        description: str(body.description),
      };
    case 'manufacturers':
      return {
        name: str(body.name),
        country: str(body.country),
        city: str(body.city),
        foundedYear: num(body.foundedYear),
        email: str(body.email),
        website: str(body.website),
        materialIds: ids(body.materialIds),
        description: str(body.description),
      };
    case 'categories':
      return { name: str(body.name), description: str(body.description) };
    case 'materials':
      return { name: str(body.name), kind: str(body.kind), origin: str(body.origin) };
    case 'customers':
      return { fullName: str(body.fullName), email: str(body.email).toLowerCase(), phone: str(body.phone) };
    default:
      return { ...body };
  }
}

/** Сохраняет карту покупателя: создаёт, меняет или удаляет. */
function saveCard(customerId, card) {
  const existing = cardOf(customerId);
  if (!card) {
    if (existing) db.cards.splice(db.cards.indexOf(existing), 1);
    return;
  }
  const data = {
    number: str(card.number),
    discountPercent: Number(card.discountPercent),
    issuedAt: new Date(card.issuedAt).toISOString(),
  };
  if (existing) Object.assign(existing, data);
  else db.cards.push({ id: ++db.seq.cards, customerId, ...data });
}

// ─────────────────────────── ссылочная целостность ───────────────────────────

/** Сколько товаров (включая логически удалённые) ссылается на запись. */
function usage(collection, id) {
  switch (collection) {
    case 'manufacturers': return db.products.filter((p) => p.manufacturerId === id).length;
    case 'categories': return db.products.filter((p) => p.categoryIds.includes(id)).length;
    case 'materials': return db.products.filter((p) => p.materialIds.includes(id)).length;
    case 'products': return db.orders.filter((o) => o.productId === id && !o.cancelledAt).length;
    case 'customers': return db.orders.filter((o) => o.customerId === id && !o.cancelledAt).length;
    default: return 0;
  }
}

function plural(n, one, few, many) {
  const m10 = n % 10, m100 = n % 100;
  if (m10 === 1 && m100 !== 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

function usageMessage(collection, row, count) {
  const name = row.name || row.fullName || `№ ${row.id}`;
  switch (collection) {
    case 'manufacturers': return `Нельзя удалить «${name}»: на него ссылаются ${count} ${plural(count, 'товар', 'товара', 'товаров')}.`;
    case 'categories': return `Нельзя удалить «${name}»: в ней ${count} ${plural(count, 'товар', 'товара', 'товаров')}.`;
    case 'materials': return `Нельзя удалить «${name}»: он используется в ${count} ${plural(count, 'товаре', 'товарах', 'товарах')}.`;
    case 'products': return `Нельзя удалить «${name}»: по нему есть незакрытые заказы (${count}).`;
    case 'customers': return `Нельзя удалить «${name}»: у покупателя есть незакрытые заказы (${count}).`;
    default: return 'Запись используется другими записями.';
  }
}

// ──────────────────────────── HTTP-обвязка ────────────────────────────

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Vary', 'Origin');
}

function send(res, status, payload) {
  cors(res);
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, status, message) {
  send(res, status, { message });
}

function invalid(res, errors) {
  send(res, 422, { message: 'Ошибка валидации', errors });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null;
  }
}

function currentUser(req) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = verify(header.slice(7));
  if (!payload || payload.type !== 'access') return null;
  return db.users.find((u) => u.id === payload.sub && !u.deletedAt) || null;
}

const ROLE_LEVEL = { viewer: 1, manager: 2, admin: 3 };

function requireRole(res, user, minRole) {
  if (!user) {
    fail(res, 401, 'Требуется аутентификация');
    return false;
  }
  if (ROLE_LEVEL[user.role] < ROLE_LEVEL[minRole]) {
    fail(res, 403, `Операция доступна начиная с роли «${minRole}»`);
    return false;
  }
  return true;
}

const expandUser = (u) => ({ id: u.id, username: u.username, fullName: u.fullName, role: u.role });

function issueTokens(user) {
  const now = Math.floor(Date.now() / 1000);
  const accessToken = sign({ sub: user.id, role: user.role, type: 'access', exp: now + ACCESS_TTL });
  const refreshToken = sign({ sub: user.id, type: 'refresh', exp: now + REFRESH_TTL });
  db.refreshTokens.add(refreshToken);
  return { accessToken, refreshToken, expiresIn: ACCESS_TTL, user: expandUser(user) };
}

// ─────────────────────────────── маршруты ───────────────────────────────

async function handle(req, res, url) {
  const q = Object.fromEntries(url.searchParams.entries());
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();
  const user = currentUser(req);

  if (q.__fail) {
    return fail(res, Number(q.__fail), 'Ошибка вызвана намеренно параметром __fail');
  }

  // ── служебные ──
  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Данные восстановлены в исходное состояние' });
  }
  if (path === '/api/__health' && method === 'GET') {
    return send(res, 200, { status: 'ok', time: new Date().toISOString() });
  }

  // ── аутентификация ──
  if (path === '/api/auth/login' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
    const found = db.users.find((u) => u.username === String(body.username || '').trim() && !u.deletedAt);
    if (!found || found.passwordHash !== hash(String(body.password || ''))) {
      return fail(res, 401, 'Неверный логин или пароль');
    }
    return send(res, 200, issueTokens(found));
  }
  if (path === '/api/auth/refresh' && method === 'POST') {
    const body = await readBody(req);
    const token = body && body.refreshToken;
    const payload = verify(token);
    if (!payload || payload.type !== 'refresh' || !db.refreshTokens.has(token)) {
      return fail(res, 401, 'Токен обновления недействителен');
    }
    const found = db.users.find((u) => u.id === payload.sub);
    if (!found) return fail(res, 401, 'Пользователь не найден');
    db.refreshTokens.delete(token);
    return send(res, 200, issueTokens(found));
  }
  if (path === '/api/auth/me' && method === 'GET') {
    if (!user) return fail(res, 401, 'Требуется аутентификация');
    return send(res, 200, expandUser(user));
  }
  if (path === '/api/auth/logout' && method === 'POST') {
    const body = await readBody(req);
    if (body && body.refreshToken) db.refreshTokens.delete(body.refreshToken);
    return send(res, 204);
  }

  // ── заказы: оформление и отмена ──
  if (path === '/api/orders' && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const customer = alive('customers', body.customerId);
    const product = alive('products', body.productId);
    if (!customer) errors.customerId = 'Покупатель не найден';
    if (!product) errors.productId = 'Товар не найден';
    const quantity = Number(body.quantity || 1);
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 100) errors.quantity = 'Количество от 1 до 100';
    if (Object.keys(errors).length) return invalid(res, errors);

    if (product.stock < quantity) {
      return fail(
        res,
        409,
        product.stock === 0
          ? `Товара «${product.name}» нет на складе`
          : `На складе только ${product.stock} шт. товара «${product.name}»`
      );
    }

    const card = cardOf(customer.id);
    const discount = card ? card.discountPercent : 0;
    const total = Math.round(product.price * quantity * (100 - discount) / 100);
    product.stock -= quantity;
    const order = push('orders', { customerId: customer.id, productId: product.id, quantity, total, cancelledAt: null });
    return send(res, 201, expandOrder(order));
  }

  let m = path.match(/^\/api\/orders\/(\d+)\/cancel$/);
  if (m && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const order = alive('orders', m[1]);
    if (!order) return fail(res, 404, 'Заказ не найден');
    if (order.cancelledAt) return fail(res, 409, 'Заказ уже отменён');
    order.cancelledAt = new Date().toISOString();
    const product = byId('products', order.productId);
    if (product) product.stock += order.quantity;
    return send(res, 200, expandOrder(order));
  }

  // ── единообразный CRUD ──
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);
  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    if (!requireRole(res, user, 'manager')) return;

    const body = await readBody(req);
    const ids = Array.isArray(body && body.ids) ? body.ids.map(Number) : [];
    if (!ids.length) return invalid(res, { ids: 'Передайте непустой список идентификаторов' });

    const targets = db[collection].filter((row) => ids.includes(row.id) && !row.deletedAt);
    const blocked = targets
      .map((row) => [row, usage(collection, row.id)])
      .filter(([, count]) => count > 0)
      .map(([row, count]) => usageMessage(collection, row, count));
    if (blocked.length) return fail(res, 409, 'Ничего не удалено. ' + blocked.join(' '));

    const now = new Date().toISOString();
    targets.forEach((row) => { row.deletedAt = now; });
    return send(res, 200, { deleted: targets.length });
  }

  m = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore))?$/);
  if (m) {
    const collection = m[1];
    const id = m[2] ? Number(m[2]) : null;
    const action = m[3] || null;

    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    const expand = EXPANDERS[collection];

    if (action === 'restore' && method === 'POST') {
      if (!requireRole(res, user, 'admin')) return;
      const row = byId(collection, id);
      if (!row) return fail(res, 404, 'Объект не найден');
      row.deletedAt = null;
      return send(res, 200, expand(row));
    }

    if (id === null && method === 'GET') {
      let rows = db[collection];
      if (q.includeDeleted !== 'true') rows = rows.filter((x) => !x.deletedAt);
      rows = applyFilters(collection, rows, q);
      rows = applySort(collection, rows, q.sort);
      const page = paginate(rows, q);
      return send(res, 200, { ...page, items: page.items.map(expand) });
    }

    if (id !== null && method === 'GET') {
      const row = db[collection].find((x) => x.id === id && (q.includeDeleted === 'true' || !x.deletedAt));
      if (!row) return fail(res, 404, 'Объект не найден');
      return send(res, 200, expand(row));
    }

    if (collection === 'orders' && method !== 'DELETE') {
      return fail(res, 404, 'Заказы оформляются через POST /api/orders');
    }

    if (id === null && method === 'POST') {
      if (!requireRole(res, user, 'manager')) return;
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
      const errors = validate(collection, body);
      if (Object.keys(errors).length) return invalid(res, errors);
      const row = push(collection, normalize(collection, body));
      if (collection === 'customers') saveCard(row.id, body.card);
      return send(res, 201, expand(row));
    }

    if (id !== null && (method === 'PUT' || method === 'PATCH')) {
      if (!requireRole(res, user, 'manager')) return;
      const row = db[collection].find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
      const merged = method === 'PATCH' ? { ...row, ...body } : body;
      const errors = validate(collection, merged, id);
      if (Object.keys(errors).length) return invalid(res, errors);
      Object.assign(row, normalize(collection, merged));
      if (collection === 'customers' && (method === 'PUT' || 'card' in body)) saveCard(row.id, merged.card);
      return send(res, 200, expand(row));
    }

    if (id !== null && method === 'DELETE') {
      const hard = q.hard === 'true';
      if (!requireRole(res, user, hard ? 'admin' : 'manager')) return;
      const index = db[collection].findIndex((x) => x.id === id);
      if (index === -1) return fail(res, 404, 'Объект не найден');
      const row = db[collection][index];

      const count = usage(collection, id);
      if (count > 0) return fail(res, 409, usageMessage(collection, row, count));

      if (hard) {
        db[collection].splice(index, 1);
        if (collection === 'customers') saveCard(id, null);
      } else {
        row.deletedAt = new Date().toISOString();
      }
      return send(res, 204);
    }
  }

  return fail(res, 404, `Адрес ${method} ${path} не обслуживается`);
}

// ─────────────────────────── статические файлы ───────────────────────────

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.css': 'text/css', '.png': 'image/png', '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.frag': 'application/octet-stream', '.bin': 'application/octet-stream',
};

function serveStatic(pathname, res) {
  const root = pathLib.resolve(STATIC_DIR);
  let file = pathLib.join(root, decodeURIComponent(pathname));
  if (!file.startsWith(root)) { res.writeHead(403); return res.end(); }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    // Адреса приложения (/products/5) отдают index.html — маршрутизацией
    // занимается само приложение.
    file = pathLib.join(root, 'index.html');
  }
  res.writeHead(200, { 'Content-Type': MIME[pathLib.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}

// ─────────────────────────────── запуск ───────────────────────────────

seed();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  // Предварительный запрос браузера (CORS preflight).
  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }

  if (STATIC_DIR && !url.pathname.startsWith('/api/')) {
    return serveStatic(url.pathname, res);
  }

  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((r) => setTimeout(r, Math.min(delay, 10000)));

  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера: ' + err.message);
  }
  console.log(`${req.method.padEnd(6)} ${url.pathname}${url.search}  → ${res.statusCode}  ${Date.now() - started} мс`);
});

server.listen(PORT, () => {
  console.log('');
  console.log('  Учебное API «МебельДом»');
  console.log(`  Адрес:                http://localhost:${PORT}/api`);
  console.log(`  Разрешённый источник: ${ORIGIN}`);
  if (STATIC_DIR) console.log(`  Приложение:           http://localhost:${PORT}/ (${STATIC_DIR})`);
  console.log(`  Срок жизни токена:    ${ACCESS_TTL} с`);
  console.log('');
  console.log('  Учётные записи:  admin/admin123   manager/manager123   viewer/viewer123');
  console.log('  Сброс данных:    POST /api/__reset');
  console.log('  Задержка ответа: любой запрос с ?__delay=1500');
  console.log('  Ошибка по требованию: любой запрос с ?__fail=500');
  console.log('');
});
