# Eazy2buy backend (Flask)

The site's **accounts and product catalogue** live here. On every page load
`../js/store.js` fetches `GET /api/bootstrap` (catalogue + signed-in account)
into a local copy that pages render from; saves update that copy at once and
go to this API in the background.

Login is a signed token (`Authorization: Bearer ...`), not a cookie: the site
and this API are on different domains, and Brave/Safari block cross-site
cookies by default.

**Still browser-only for now:** cart, orders, wallet/exchange, reviews and
agent chat stay in each visitor's `localStorage`. The order/review routes
below exist but the site doesn't call them yet. Because orders are still
local, product stock isn't reduced on the server when someone buys.

## Why it exists now

The main reason to stand this up early is the recommendation engine: a direct
Python port of the `Store.recommend()` algorithm already running client-side
(business type → category weighting, then favourites, then order history,
then popularity, picked one at a time so results mix categories). It's a
real, working baseline — not a stub — and the natural place to grow into
something heavier (collaborative filtering, embeddings over product text,
etc.) without having to also redesign the API shape at the same time.

## Setup

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows
# source .venv/bin/activate     # macOS/Linux
pip install -r requirements.txt
copy .env.example .env          # Windows: `cp .env.example .env` elsewhere
flask --app app.py seed         # loads seed_data.json (ported from ../js/data.js)
python app.py                   # serves on http://127.0.0.1:5000
```

`flask --app app.py seed` is safe to re-run — it upserts by id rather than
duplicating rows. It also creates the demo admin user from `data.js`
(`admin@demo.com`), with the password from `ADMIN_PASSWORD` in `.env` — or, if
that's unset, a random one printed once to the console/log.

To actually use the "Generate" button in AiStudio:
1. Get an OpenAI API key at https://platform.openai.com/api-keys (needs
   billing enabled on the account — image generation isn't free).
2. Put it in `backend/.env` as `OPENAI_API_KEY=sk-...`.
3. In `js/config.js`, set `AI_DESIGN_ENDPOINT` to
   `'http://127.0.0.1:5000/api/design/generate'`.
4. Run the backend (`python app.py`) and open `studio.html` through a local
   static server (not `file://`, or the fetch will be blocked).

## Live deployment (EC2)

Running at **https://m2c.13-48-31-7.sslip.io** (e.g. `/api/health`), on the
same EC2 box and in the same style as the other apps there:

| Piece | Where |
|---|---|
| Code | `/home/ubuntu/m2c-app` (git clone of this repo), app in `backend/` |
| Process | `m2c.service` (systemd) → gunicorn on `127.0.0.1:3005` |
| Web | nginx site `/etc/nginx/sites-available/m2c`, Let's Encrypt cert via certbot |
| Database | local Postgres, database + user `m2c` |
| Secrets | `/home/ubuntu/m2c-app/backend/.env` (not in git) |

To ship new backend code after pushing to GitHub:

```bash
ssh -i fadex.pem ubuntu@13.48.31.7
cd ~/m2c-app && git pull
backend/venv/bin/pip install -q -r backend/requirements.txt   # only if requirements changed
sudo systemctl restart m2c && sudo systemctl status m2c --no-pager
```

Logs: `sudo journalctl -u m2c -n 100 --no-pager`. To enable AI Generate, add
your key to `OPENAI_API_KEY=` in that `.env`, then `sudo systemctl restart m2c`.

## Deploying on Render (alternative)

The static site (https://m2c-app-vqeb.onrender.com) stays exactly as it is —
this API is already set to accept requests from it. Add the API as a second,
separate Render service:

1. **New → PostgreSQL** (free tier is fine). Copy its **Internal Database URL**.
   Use Postgres rather than the default SQLite: Render's web-service disk is
   wiped on every deploy/restart, so SQLite data wouldn't survive.
2. **New → Web Service**, same GitHub repo, with:
   - **Root Directory:** `backend`
   - **Runtime:** Python
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `gunicorn app:app`
3. **Environment** tab on that web service:
   - `DATABASE_URL` = the Postgres internal URL from step 1
   - `SECRET_KEY` = any long random string
   - `CROSS_SITE_COOKIES` = `1`
   - `OPENAI_API_KEY` = your key (only needed for AiStudio's Generate button)
4. Deploy. On first start the app creates its tables and loads the catalogue
   from `seed_data.json` by itself — no shell needed. Check it at
   `https://<your-api>.onrender.com/api/health`.
5. In the frontend's `js/config.js`, set `AI_DESIGN_ENDPOINT` to
   `'https://<your-api>.onrender.com/api/design/generate'` and push, so the
   static site picks it up.

Free Render web services sleep after ~15 minutes idle, so the first request
after a quiet spell takes 30–60 seconds while it wakes up.

## What's here

It's one file, `app.py`, laid out top to bottom as: Flask app + extensions +
config → models → helpers ported from the frontend → the recommendation
algorithm → routes, grouped by resource → the seed command. Each section is
marked with a comment banner, so searching for e.g. `# 6. Routes` jumps
straight there.

- **Models** — `Category`, `BusinessType`, `Agent`, `User`, `Product`,
  `Order`/`OrderItem`, `Review`, `CartItem`. Field names follow the
  frontend's camelCase in `to_dict()` output so a future fetch() call can
  drop straight into the existing render code with minimal changes.
- **`seed_data.json`** — exported from `../js/data.js` (all 91 products, 14
  categories, business types, agents). Re-export it if the frontend catalogue
  changes: run a Node script that `vm.runInContext`s `data.js` and dumps the
  seed consts to JSON (not included here, since it's a one-off).
- **Routes** — grouped by resource (`auth`, `categories`, `products`,
  `orders`, `reviews`, `recommendations`) within the single file. Auth is
  cookie-session based (Flask-Login), matching what a same-site static
  frontend would use.
- **`is_customizable()` / `discount_of()`** — ported from `../js/ui.js` so
  "customisable only" filtering and discount sorting agree with the
  frontend's rules.

## Endpoints

| Method | Path | Notes |
|---|---|---|
| GET | `/api/health` | liveness check |
| GET | `/api/categories` | all categories |
| GET | `/api/products` | query params: `cat`, `sub`, `condition`, `q`, `max`, `sort` (`popular`\|`low`\|`high`\|`discount`\|`rating`), `custom=1` |
| GET | `/api/products/<id>` | single product |
| GET | `/api/products/<id>/reviews` | reviews for a product |
| POST | `/api/products/<id>/reviews` | `{ rating, text }`, requires login |
| GET | `/api/bootstrap` | catalogue + signed-in account (+ all accounts for an admin); what every page loads |
| POST | `/api/auth/signup` | `{ name, email, phone, password, profile? }` → `{ user, token }` |
| POST | `/api/auth/login` | `{ email, password }` → `{ user, token }` |
| GET | `/api/auth/me` | signed-in account, or `null` |
| PATCH | `/api/auth/me` | the site's copy of the account + `_seq`; older `_seq` is ignored |
| PATCH | `/api/admin/users/<id>` | admin only; changed fields, e.g. `{ verify }` |
| PUT / DELETE | `/api/admin/products/<id>` | admin only; create/update or delete |
| PUT / DELETE | `/api/admin/categories/<id>` | admin only; create/update or delete |
| GET | `/api/orders` | current user's orders, requires login |
| POST | `/api/orders` | `{ items: [{ productId, qty, custom? }], address, pay }`, requires login |
| GET | `/api/orders/<id>` | requires login; owner or admin only |
| GET | `/api/recommendations` | `?limit=15`; personalised if logged in, popularity-sorted otherwise |
| POST | `/api/design/generate` | `{ prompt, productName? }` → `{ image: "data:image/png;base64,..." }`. **No login required** — see the warning in `app.py` section 7 before this goes anywhere public. |

"Requires login" means an `Authorization: Bearer <token>` header from signup/login.

## Not built yet

Deliberately left out until there's a real reason to add them: cart
persistence server-side (orders currently take `items` directly in the
request body instead), wallet/exchange, business-agent chat, admin
endpoints, KYC photo upload, and saved-design storage (a generated image is
handed back once and not kept on the server). Add them the same way as the
existing routes when the frontend actually needs them.

## Connecting the rest of it later

When it's time to wire up everything else: point `fetch()` calls in the
frontend's `js/store.js` at these endpoints, set `CORS_ORIGINS` in `.env` to
wherever the static site is served from, and keep `credentials: 'include'`
on every `fetch()` call so the session cookie goes along with it. Then add
real auth to `/api/design/generate` too, since right now it's reachable by
anyone who knows the URL.
