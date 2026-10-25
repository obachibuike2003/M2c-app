"""Easy2buy backend - single-file Flask app.

Not connected to the frontend yet (see README.md). Run it with:
    python app.py
Seed the database with:
    flask --app app.py seed

Everything that used to be split across app/models.py, app/routes/*.py,
app/recommendations.py etc. lives in this one file now, in this order:
  1. App + extensions setup
  2. Config
  3. Models
  4. Small helpers ported from the frontend (is_customizable, discount_of)
  5. Recommendation algorithm
  6. Routes, grouped by resource
  7. AI image generation (OpenAI) - the one feature actually wired up to
     a real frontend call right now (AiStudio's "Generate" button)
  8. Seed command
"""

import json
import math
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path

import click
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_login import (LoginManager, UserMixin, current_user, login_required,
                          login_user, logout_user)
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import check_password_hash, generate_password_hash

load_dotenv()


# ---------------------------------------------------------------------------
# 1-2. App, extensions and config
# ---------------------------------------------------------------------------

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-secret-not-for-production")
# Postgres URLs ("postgres://" or "postgresql://") are routed through pg8000, a
# pure-Python driver, so no compiled database driver is needed on the server.
_db_url = os.environ.get("DATABASE_URL", "sqlite:///easy2buy.db")
_db_url = re.sub(r"^postgres(ql)?://", "postgresql+pg8000://", _db_url)
app.config["SQLALCHEMY_DATABASE_URI"] = _db_url
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Kept in step with the values in ../js/config.js so totals match once connected.
SHIPPING_FEE = 2500
FREE_SHIPPING_FROM = 50000
BULK_MIN_QTY = 10
BULK_TIERS = [{"from": 10, "off": 5}, {"from": 50, "off": 10}, {"from": 100, "off": 15}]

db = SQLAlchemy(app)
login_manager = LoginManager(app)

# The static frontend lives on a different domain, so the browser needs CORS
# permission to call this API. Override with CORS_ORIGINS (comma-separated).
FRONTEND_URL = "https://m2c-app-vqeb.onrender.com"
CORS_ORIGINS = [o.strip() for o in os.environ.get("CORS_ORIGINS", "").split(",") if o.strip()]
CORS(app, supports_credentials=True, origins=CORS_ORIGINS or [FRONTEND_URL])

# Frontend and API on different domains means the login cookie is cross-site,
# which browsers only send when it's SameSite=None and Secure (HTTPS only).
if os.environ.get("CROSS_SITE_COOKIES", "1") == "1":
    app.config.update(SESSION_COOKIE_SAMESITE="None", SESSION_COOKIE_SECURE=True,
                      REMEMBER_COOKIE_SAMESITE="None", REMEMBER_COOKIE_SECURE=True)

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")


def now():
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# 3. Models - mirror the shape of ../js/data.js and ../js/store.js, so when
# the frontend is wired up the swap is mostly replacing Store.* calls with
# fetch() calls to this API.
# ---------------------------------------------------------------------------

class Category(db.Model):
    __tablename__ = "categories"

    id = db.Column(db.String(40), primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    icon = db.Column(db.String(40), default="box")
    hue = db.Column(db.Integer, default=220)
    img = db.Column(db.String(255), default="")

    products = db.relationship("Product", back_populates="category")

    def to_dict(self):
        return {"id": self.id, "name": self.name, "icon": self.icon, "hue": self.hue, "img": self.img}


class BusinessType(db.Model):
    __tablename__ = "business_types"

    id = db.Column(db.String(40), primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    cats = db.Column(db.JSON, default=list)  # categories this type is steered towards, in priority order

    def to_dict(self):
        return {"id": self.id, "name": self.name, "cats": self.cats or []}


class Agent(db.Model):
    __tablename__ = "agents"

    id = db.Column(db.String(40), primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    phone = db.Column(db.String(40))
    whatsapp = db.Column(db.String(40))

    def to_dict(self):
        return {"id": self.id, "name": self.name, "phone": self.phone, "whatsapp": self.whatsapp}


class User(db.Model, UserMixin):
    __tablename__ = "users"

    id = db.Column(db.String(40), primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    phone = db.Column(db.String(40))
    whatsapp = db.Column(db.String(40))
    password_hash = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), default="customer")  # customer | admin
    mode = db.Column(db.String(20), default="personal")  # personal | business

    business_name = db.Column(db.String(120))
    business_type_id = db.Column(db.String(40), db.ForeignKey("business_types.id"))
    agent_id = db.Column(db.String(40), db.ForeignKey("agents.id"))

    verify_status = db.Column(db.String(20), default="none")  # none | pending | verified | rejected

    balances = db.Column(db.JSON, default=dict)  # per currency code, e.g. {"NGN": 50000}
    favs = db.Column(db.JSON, default=list)  # favourited product ids

    created_at = db.Column(db.DateTime, default=now)

    business_type = db.relationship("BusinessType")
    agent = db.relationship("Agent")
    orders = db.relationship("Order", back_populates="user")
    reviews = db.relationship("Review", back_populates="user")

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self, include_private=False):
        data = {
            "id": self.id, "name": self.name, "role": self.role, "mode": self.mode,
            "businessName": self.business_name, "businessType": self.business_type_id,
            "agentId": self.agent_id, "verifyStatus": self.verify_status,
        }
        if include_private:
            data.update({"email": self.email, "phone": self.phone, "whatsapp": self.whatsapp,
                         "balances": self.balances or {}, "favs": self.favs or []})
        return data


class Product(db.Model):
    __tablename__ = "products"

    id = db.Column(db.String(40), primary_key=True)
    cat_id = db.Column(db.String(40), db.ForeignKey("categories.id"), nullable=False, index=True)
    sub = db.Column(db.String(80))
    name = db.Column(db.String(200), nullable=False)
    price = db.Column(db.Integer, nullable=False)
    old_price = db.Column(db.Integer, default=0)
    rating = db.Column(db.Float, default=0)
    sold = db.Column(db.Integer, default=0)
    stock = db.Column(db.Integer, default=0)
    ship = db.Column(db.String(20), default="7-15")
    condition = db.Column(db.String(10), default="new")  # new | used
    bulk_min = db.Column(db.Integer)  # overrides the default bulk minimum when set
    img = db.Column(db.String(255), default="")
    imgs = db.Column(db.JSON, default=list)
    desc = db.Column(db.Text, default="")

    category = db.relationship("Category", back_populates="products")
    reviews = db.relationship("Review", back_populates="product")

    def to_dict(self):
        return {
            "id": self.id, "cat": self.cat_id, "sub": self.sub, "name": self.name,
            "price": self.price, "oldPrice": self.old_price, "rating": self.rating,
            "sold": self.sold, "stock": self.stock, "ship": self.ship,
            "condition": self.condition, "bulkMin": self.bulk_min,
            "img": self.img, "imgs": self.imgs or [], "desc": self.desc,
        }


class Order(db.Model):
    __tablename__ = "orders"

    id = db.Column(db.String(40), primary_key=True)  # e.g. ORD-AB12CD
    user_id = db.Column(db.String(40), db.ForeignKey("users.id"), nullable=False, index=True)
    mode = db.Column(db.String(20), default="personal")
    status = db.Column(db.String(40), default="Order placed")
    stage = db.Column(db.Integer, default=0)
    subtotal = db.Column(db.Integer, default=0)
    delivery_fee = db.Column(db.Integer, default=0)
    total = db.Column(db.Integer, default=0)
    address = db.Column(db.JSON, default=dict)
    pay = db.Column(db.String(20), default="wallet")
    tracking = db.Column(db.JSON, default=list)  # [{"stage": 0, "at": "..."}]
    created_at = db.Column(db.DateTime, default=now)
    cancelled_at = db.Column(db.DateTime)

    user = db.relationship("User", back_populates="orders")
    items = db.relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id, "userId": self.user_id, "mode": self.mode, "status": self.status,
            "stage": self.stage, "subtotal": self.subtotal, "deliveryFee": self.delivery_fee,
            "total": self.total, "address": self.address, "pay": self.pay,
            "tracking": self.tracking or [], "createdAt": self.created_at.isoformat() if self.created_at else None,
            "cancelledAt": self.cancelled_at.isoformat() if self.cancelled_at else None,
            "items": [i.to_dict() for i in self.items],
        }


class OrderItem(db.Model):
    __tablename__ = "order_items"

    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.String(40), db.ForeignKey("orders.id"), nullable=False)
    product_id = db.Column(db.String(40), db.ForeignKey("products.id"), nullable=False)
    name = db.Column(db.String(200), nullable=False)  # snapshotted at order time
    price = db.Column(db.Integer, nullable=False)  # snapshotted unit price
    qty = db.Column(db.Integer, nullable=False)
    custom = db.Column(db.JSON)  # logo/colour/notes for a customised line, or null

    order = db.relationship("Order", back_populates="items")

    def to_dict(self):
        return {"id": self.product_id, "name": self.name, "price": self.price, "qty": self.qty, "custom": self.custom}


class Review(db.Model):
    __tablename__ = "reviews"

    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.String(40), db.ForeignKey("products.id"), nullable=False, index=True)
    user_id = db.Column(db.String(40), db.ForeignKey("users.id"), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    text = db.Column(db.Text, default="")
    created_at = db.Column(db.DateTime, default=now)

    product = db.relationship("Product", back_populates="reviews")
    user = db.relationship("User", back_populates="reviews")

    def to_dict(self):
        return {
            "id": self.id, "productId": self.product_id,
            "userName": self.user.name.split(" ")[0] if self.user else "",
            "rating": self.rating, "text": self.text,
            "at": self.created_at.isoformat() if self.created_at else None,
        }


class CartItem(db.Model):
    __tablename__ = "cart_items"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(40), db.ForeignKey("users.id"), nullable=False, index=True)
    product_id = db.Column(db.String(40), db.ForeignKey("products.id"), nullable=False)
    qty = db.Column(db.Integer, nullable=False, default=1)
    custom = db.Column(db.JSON)  # a customised line never merges with a plain one

    def to_dict(self):
        return {"id": self.id, "productId": self.product_id, "qty": self.qty, "custom": self.custom}


@login_manager.user_loader
def load_user(user_id):
    return db.session.get(User, user_id)


@login_manager.unauthorized_handler
def unauthorized():
    return jsonify({"error": "Please sign in first."}), 401


# ---------------------------------------------------------------------------
# 4. Small helpers ported from ../js/ui.js, so the two sides agree on rules
# like "which products can carry a buyer's own logo" until the frontend
# actually calls this API and these can be deleted from one side.
# ---------------------------------------------------------------------------

_UNBRANDABLE_NAME = re.compile(
    r"\b(apple|samsung|huawei|oppo|realme|vivo|lenovo|beats|amazon|nokia|xiaomi|tecno|infinix|"
    r"sony|jbl|bose|hp|dell|asus|nike|adidas|puma|chrysler|dodge|toyota|honda|ford|hyundai|kia|"
    r"mercedes|bmw|lexus|jeep|nissan)\b",
    re.IGNORECASE,
)


def is_customizable(product):
    return product.cat_id != "cars" and not _UNBRANDABLE_NAME.search(product.name)


def discount_of(product):
    if product.old_price and product.old_price > product.price:
        return round((1 - product.price / product.old_price) * 100)
    return 0


# ---------------------------------------------------------------------------
# 5. Recommendations. recommend_products() is a direct port of the
# Store.recommend() logic that already runs client-side in ../js/store.js:
# business type steers the category mix, then favourites and past orders add
# weight, then popularity (sold count) breaks ties - picked one at a time so
# the list mixes categories instead of filling up with whichever one scores
# highest.
#
# This is the place to grow into something heavier later - collaborative
# filtering from order/favourite co-occurrence, embeddings over product
# title/description, etc. Keep the signature (user, products, ..., limit)
# -> list[Product] stable so the /api/recommendations route doesn't need to
# change when the internals do.
# ---------------------------------------------------------------------------

def recommend_products(user, products, orders_by_product_ids=None, limit=15):
    in_stock = [p for p in products if p.stock > 0]

    if user is None:
        return sorted(in_stock, key=lambda p: -(p.sold or 0))[:limit]

    weight = {}

    def add(cat_id, w):
        if cat_id:
            weight[cat_id] = weight.get(cat_id, 0) + w

    if user.mode == "business" and user.business_type:
        for i, cat_id in enumerate(user.business_type.cats or []):
            add(cat_id, 6 - i * 1.5)

    by_id = {p.id: p for p in products}
    for fav_id in (user.favs or []):
        p = by_id.get(fav_id)
        if p:
            add(p.cat_id, 2)

    for prod_id in (orders_by_product_ids or []):
        p = by_id.get(prod_id)
        if p:
            add(p.cat_id, 1)

    def score(p):
        return weight.get(p.cat_id, 0) + math.log10((p.sold or 0) + 10) / 2

    # Pick one at a time, making each extra item from the same category count
    # a little less, so the list mixes categories instead of filling up with
    # just the single highest-scoring one.
    picked = []
    used = {}
    pool = list(in_stock)
    while len(picked) < limit and pool:
        best_i = 0
        best_val = score(pool[0]) - used.get(pool[0].cat_id, 0) * 1.6
        for i, p in enumerate(pool):
            val = score(p) - used.get(p.cat_id, 0) * 1.6
            if val > best_val:
                best_i, best_val = i, val
        chosen = pool.pop(best_i)
        used[chosen.cat_id] = used.get(chosen.cat_id, 0) + 1
        picked.append(chosen)

    return picked


# ---------------------------------------------------------------------------
# 6. Routes
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health():
    return jsonify({"ok": True})


# --- categories --------------------------------------------------------

@app.get("/api/categories")
def list_categories():
    rows = Category.query.order_by(Category.name).all()
    return jsonify([c.to_dict() for c in rows])


# --- products ------------------------------------------------------------

SORTERS = {
    "popular": lambda p: -(p.sold or 0),
    "low": lambda p: p.price,
    "high": lambda p: -p.price,
    "discount": lambda p: -discount_of(p),
    "rating": lambda p: -(p.rating or 0),
}


@app.get("/api/products")
def list_products():
    q = Product.query
    cat = request.args.get("cat")
    sub = request.args.get("sub")
    condition = request.args.get("condition")
    search = (request.args.get("q") or "").strip().lower()
    max_price = request.args.get("max", type=int)
    custom_only = request.args.get("custom") == "1"
    sort = request.args.get("sort", "popular")

    if cat:
        q = q.filter(Product.cat_id == cat)
    if sub:
        q = q.filter(Product.sub == sub)
    if condition in ("new", "used"):
        q = q.filter(Product.condition == condition)
    if max_price:
        q = q.filter(Product.price <= max_price)

    rows = q.all()
    if search:
        rows = [p for p in rows if search in (p.name + " " + (p.desc or "")).lower()]
    if custom_only:
        rows = [p for p in rows if is_customizable(p)]
    rows.sort(key=SORTERS.get(sort, SORTERS["popular"]))

    return jsonify({"count": len(rows), "products": [p.to_dict() for p in rows]})


@app.get("/api/products/<product_id>")
def get_product(product_id):
    p = Product.query.get(product_id)
    if not p:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(p.to_dict())


# --- reviews ---------------------------------------------------------------

@app.get("/api/products/<product_id>/reviews")
def list_reviews(product_id):
    rows = Review.query.filter_by(product_id=product_id).order_by(Review.created_at.desc()).all()
    return jsonify([r.to_dict() for r in rows])


@app.post("/api/products/<product_id>/reviews")
@login_required
def add_review(product_id):
    if not Product.query.get(product_id):
        return jsonify({"error": "Product not found"}), 404

    data = request.get_json(silent=True) or {}
    rating = int(data.get("rating") or 0)
    if not (1 <= rating <= 5):
        return jsonify({"error": "Pick a star rating."}), 400

    review = Review(product_id=product_id, user_id=current_user.id, rating=rating, text=(data.get("text") or "").strip())
    db.session.add(review)
    db.session.commit()
    return jsonify(review.to_dict()), 201


# --- auth --------------------------------------------------------------

EMAIL_RE = re.compile(r"^\S+@\S+\.\S+$")


@app.post("/api/auth/signup")
def signup():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    phone = (data.get("phone") or "").strip()
    password = data.get("password") or ""

    if not name:
        return jsonify({"error": "Enter your full name."}), 400
    if not EMAIL_RE.match(email):
        return jsonify({"error": "Enter a valid email address."}), 400
    if len(password) < 6:
        return jsonify({"error": "Your password needs at least 6 characters."}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({"error": "An account with this email already exists."}), 409

    user = User(id="u_" + uuid.uuid4().hex[:12], name=name, email=email, phone=phone,
                whatsapp=data.get("whatsapp") or phone, balances={}, favs=[])
    user.set_password(password)
    db.session.add(user)
    db.session.commit()

    login_user(user)
    return jsonify(user.to_dict(include_private=True)), 201


@app.post("/api/auth/login")
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({"error": "Wrong email or password."}), 401

    login_user(user)
    return jsonify(user.to_dict(include_private=True))


@app.post("/api/auth/logout")
@login_required
def logout():
    logout_user()
    return jsonify({"ok": True})


@app.get("/api/auth/me")
def me():
    if not current_user.is_authenticated:
        return jsonify(None)
    return jsonify(current_user.to_dict(include_private=True))


# --- orders ------------------------------------------------------------

@app.get("/api/orders")
@login_required
def list_orders():
    rows = Order.query.filter_by(user_id=current_user.id).order_by(Order.created_at.desc()).all()
    return jsonify([o.to_dict() for o in rows])


@app.get("/api/orders/<order_id>")
@login_required
def get_order(order_id):
    o = Order.query.get(order_id)
    if not o or (o.user_id != current_user.id and current_user.role != "admin"):
        return jsonify({"error": "Order not found"}), 404
    return jsonify(o.to_dict())


@app.post("/api/orders")
@login_required
def place_order():
    """Body: { items: [{ productId, qty, custom? }], address: {...}, pay: "wallet"|"delivery" }
    This takes the items directly rather than reading a server-side cart, since
    there's no cart endpoint wired up yet either - add one and swap this out
    for `cart_lines_for(current_user)` when the frontend is connected."""
    data = request.get_json(silent=True) or {}
    items = data.get("items") or []
    address = data.get("address") or {}
    pay = data.get("pay", "wallet")

    if not items:
        return jsonify({"error": "Your cart is empty."}), 400

    order_items = []
    subtotal = 0
    for line in items:
        product = Product.query.get(line.get("productId"))
        qty = int(line.get("qty") or 0)
        if not product or qty < 1:
            return jsonify({"error": "One of the items in your order is invalid."}), 400
        if qty > product.stock:
            return jsonify({"error": f'Only {product.stock} left of "{product.name}".'}), 400
        order_items.append(OrderItem(product_id=product.id, name=product.name, price=product.price,
                                      qty=qty, custom=line.get("custom")))
        subtotal += product.price * qty

    delivery_fee = 0 if subtotal >= FREE_SHIPPING_FROM else SHIPPING_FEE
    total = subtotal + delivery_fee

    order = Order(id="ORD-" + uuid.uuid4().hex[:6].upper(), user_id=current_user.id, mode=current_user.mode,
                  status="Order placed", stage=0, subtotal=subtotal, delivery_fee=delivery_fee, total=total,
                  address=address, pay=pay, tracking=[{"stage": 0, "at": now().isoformat()}], items=order_items)
    db.session.add(order)
    db.session.commit()

    return jsonify(order.to_dict()), 201


# --- recommendations -----------------------------------------------------

@app.get("/api/recommendations")
def get_recommendations():
    limit = request.args.get("limit", default=15, type=int)
    products = Product.query.all()

    user = current_user if current_user.is_authenticated else None
    ordered_product_ids = []
    if user:
        ordered_product_ids = [
            row.product_id for row in OrderItem.query.join(OrderItem.order).filter_by(user_id=user.id).all()
        ]

    picked = recommend_products(user, products, ordered_product_ids, limit=limit)
    return jsonify([p.to_dict() for p in picked])


# ---------------------------------------------------------------------------
# 7. AI image generation (OpenAI) - backs AiStudio's "Generate" button
# (js/pages/studio.js). The frontend never talks to OpenAI directly: it posts
# the user's prompt here, this route calls OpenAI with the API key (which
# only ever lives in this process's environment, via .env), and hands back a
# data: URL the canvas can draw like any uploaded logo.
#
# No login is required on this route because the static frontend doesn't
# have a session with this backend yet (see README) - studio.js's own
# requireBusiness() check is what gates the button in the UI today. Treat
# that as cosmetic, not security: anyone who finds this URL can call it and
# spend your OpenAI credit. Before this goes anywhere public, add real auth
# (reuse the @login_required + session-cookie pattern the other routes use,
# once the frontend is actually signing in against this backend) and/or
# rate limiting.
# ---------------------------------------------------------------------------

@app.post("/api/design/generate")
def generate_design():
    if not OPENAI_API_KEY:
        return jsonify({"error": "OPENAI_API_KEY is not set on the backend. Add it to backend/.env and restart."}), 503

    data = request.get_json(silent=True) or {}
    prompt = (data.get("prompt") or "").strip()
    if not prompt:
        return jsonify({"error": "Describe what you want before generating."}), 400

    # Steers a free-text prompt towards something that actually works placed
    # on a product: flat, centred, no mockup/background clutter.
    full_prompt = (
        f"A simple, flat logo design, centred on a plain white background, no mockup, "
        f"no watermark, no extra text unless requested: {prompt}"
    )

    try:
        res = requests.post(
            "https://api.openai.com/v1/images/generations",
            headers={"Authorization": f"Bearer {OPENAI_API_KEY}", "Content-Type": "application/json"},
            json={"model": "dall-e-3", "prompt": full_prompt, "n": 1, "size": "1024x1024",
                  "quality": "standard", "response_format": "b64_json"},
            timeout=60,
        )
    except requests.RequestException as e:
        return jsonify({"error": f"Could not reach OpenAI: {e}"}), 502

    if res.status_code != 200:
        message = "OpenAI rejected the request."
        try:
            message = res.json().get("error", {}).get("message", message)
        except ValueError:
            pass
        return jsonify({"error": message}), 502

    b64 = res.json()["data"][0]["b64_json"]
    return jsonify({"image": f"data:image/png;base64,{b64}"})


# ---------------------------------------------------------------------------
# 8. Seed command - loads seed_data.json (exported from ../js/data.js) into
# the database. Safe to re-run: upserts by id rather than duplicating rows.
#     flask --app app.py seed
# ---------------------------------------------------------------------------

SEED_PATH = Path(__file__).parent / "seed_data.json"


def seed_database():
    with open(SEED_PATH, encoding="utf-8") as f:
        data = json.load(f)

    for row in data["categories"]:
        db.session.merge(Category(id=row["id"], name=row["name"], icon=row["icon"], hue=row["hue"], img=row["img"]))

    for row in data["business_types"]:
        db.session.merge(BusinessType(id=row["id"], name=row["name"], cats=row["cats"]))

    for row in data["agents"]:
        db.session.merge(Agent(id=row["id"], name=row["name"], phone=row["phone"], whatsapp=row["whatsapp"]))

    for row in data["products"]:
        db.session.merge(Product(
            id=row["id"], cat_id=row["cat"], sub=row.get("sub"), name=row["name"],
            price=row["price"], old_price=row.get("oldPrice", 0), rating=row.get("rating", 0),
            sold=row.get("sold", 0), stock=row.get("stock", 0), ship=row.get("ship", "7-15"),
            condition=row.get("condition", "new"), bulk_min=row.get("bulkMin"),
            img=row.get("img", ""), imgs=row.get("imgs", []), desc=row.get("desc", ""),
        ))

    admin = data["demo_admin"]
    if not db.session.get(User, "u_admin"):
        user = User(id="u_admin", name=admin["name"], email=admin["email"], phone=admin["phone"], role="admin")
        user.set_password(admin["password"])
        db.session.add(user)

    db.session.commit()
    return {
        "categories": len(data["categories"]), "business_types": len(data["business_types"]),
        "agents": len(data["agents"]), "products": len(data["products"]),
    }


@app.cli.command("seed")
def seed_command():
    """Populate the database from seed_data.json."""
    counts = seed_database()
    click.echo(f"Seeded: {counts}")


with app.app_context():
    db.create_all()
    # Hosts like Render's free tier have no shell to run `flask seed`, so load
    # the catalogue automatically the first time the app starts on an empty DB.
    if not Category.query.first():
        seed_database()


if __name__ == "__main__":
    app.run(debug=bool(os.environ.get("FLASK_DEBUG", "1") == "1"))
