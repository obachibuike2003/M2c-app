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
import secrets
import uuid
from datetime import datetime, timezone
from pathlib import Path

import click
import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_login import LoginManager, UserMixin, current_user, login_required
from flask_sqlalchemy import SQLAlchemy
from functools import wraps
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
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
CORS(app, origins=CORS_ORIGINS or [FRONTEND_URL])

# Login uses a signed token the site sends as "Authorization: Bearer ...",
# not a cookie: the site and this API are on different domains, and Brave and
# Safari block cross-site cookies by default, so cookie login would fail there.
_tokens = URLSafeTimedSerializer(app.config["SECRET_KEY"], salt="auth-token")
TOKEN_MAX_AGE = 60 * 60 * 24 * 30  # 30 days


def issue_token(user):
    return _tokens.dumps(user.id)

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
    img = db.Column(db.Text, default="")  # a URL, or an uploaded image as a data: URL
    sort = db.Column(db.Integer, default=0, index=True)  # display order

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

    # Everything else the site keeps on an account (business details, brand kit,
    # address, verification, wallet balances, favourites...), in the site's own
    # shape. mode / business / favs are also mirrored into the columns above so
    # recommend_products() can use them.
    profile = db.Column(db.JSON, default=dict)

    created_at = db.Column(db.DateTime, default=now)

    business_type = db.relationship("BusinessType")
    agent = db.relationship("Agent")
    orders = db.relationship("Order", back_populates="user")
    reviews = db.relationship("Review", back_populates="user")

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        """The account in the exact shape the site's js/store.js works with."""
        return {
            **{k: v for k, v in (self.profile or {}).items() if k != "_seq"},
            "id": self.id, "name": self.name, "email": self.email, "phone": self.phone,
            "whatsapp": self.whatsapp, "role": self.role,
            "createdAt": int(self.created_at.timestamp() * 1000) if self.created_at else None,
        }

    def apply_patch(self, patch):
        """Merge site-side account changes. role and email can never be set this way."""
        prof = dict(self.profile or {})
        for key, value in (patch or {}).items():
            if key in ("name", "phone", "whatsapp"):
                setattr(self, key, str(value or "").strip()[:120])
            elif key in PROFILE_KEYS:
                prof[key] = value
        self.profile = prof  # reassigned so SQLAlchemy notices the JSON changed

        self.mode = prof.get("mode") if prof.get("mode") in ("personal", "business") else "personal"
        biz = prof.get("business") or {}
        self.business_name = (biz.get("name") or None) if isinstance(biz, dict) else None
        biz_type = biz.get("type") if isinstance(biz, dict) else None
        self.business_type_id = biz_type if biz_type and db.session.get(BusinessType, biz_type) else None
        self.favs = prof.get("favs") if isinstance(prof.get("favs"), list) else []
        verify = prof.get("verify")
        self.verify_status = verify.get("status", "none") if isinstance(verify, dict) else "none"


# Account fields the site may write through PATCH. Anything else is ignored.
PROFILE_KEYS = {"mode", "business", "brand", "verify", "address", "termsAcceptedAt",
                "balances", "favs", "agentId"}


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
    img = db.Column(db.Text, default="")  # a URL, or an uploaded image as a data: URL
    imgs = db.Column(db.JSON, default=list)
    gif = db.Column(db.Text, default="")  # optional moving view shown first in the gallery
    desc = db.Column(db.Text, default="")
    sort = db.Column(db.Integer, default=0, index=True)  # display order; new products go first

    category = db.relationship("Category", back_populates="products")
    reviews = db.relationship("Review", back_populates="product")

    def to_dict(self):
        return {
            "id": self.id, "cat": self.cat_id, "sub": self.sub, "name": self.name,
            "price": self.price, "oldPrice": self.old_price, "rating": self.rating,
            "sold": self.sold, "stock": self.stock, "ship": self.ship,
            "condition": self.condition, "bulkMin": self.bulk_min,
            "img": self.img, "imgs": self.imgs or [], "gif": self.gif or "", "desc": self.desc,
        }

    def apply(self, d):
        """Set fields from the site's product shape (as saved by the admin panel)."""
        self.cat_id = d.get("cat", self.cat_id)
        self.name = str(d.get("name", self.name) or "").strip()[:200]
        for key, attr in (("price", "price"), ("oldPrice", "old_price"), ("stock", "stock"), ("sold", "sold")):
            if key in d:
                setattr(self, attr, int(d.get(key) or 0))
        if "bulkMin" in d:
            self.bulk_min = int(d.get("bulkMin") or 0) or None
        if "rating" in d:
            self.rating = float(d.get("rating") or 0)
        for key in ("sub", "ship", "condition", "img", "gif", "desc"):
            if key in d:
                setattr(self, key, d.get(key) or ("" if key != "sub" else None))
        if "imgs" in d:
            self.imgs = d.get("imgs") or []


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


@login_manager.request_loader
def load_user_from_token(req):
    header = req.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return None
    try:
        user_id = _tokens.loads(header[7:], max_age=TOKEN_MAX_AGE)
    except (BadSignature, SignatureExpired):
        return None
    return db.session.get(User, user_id)


@login_manager.unauthorized_handler
def unauthorized():
    return jsonify({"error": "Please sign in first."}), 401


def admin_required(view):
    @wraps(view)
    @login_required
    def wrapper(*args, **kwargs):
        if current_user.role != "admin":
            return jsonify({"error": "Admins only."}), 403
        return view(*args, **kwargs)
    return wrapper


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
    rows = Category.query.order_by(Category.sort, Category.name).all()
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
                whatsapp=data.get("whatsapp") or phone, profile={})
    user.set_password(password)
    # Starting account fields from the site (empty wallet, personal mode...).
    user.apply_patch(data.get("profile") or {"mode": "personal", "favs": []})
    db.session.add(user)
    db.session.commit()

    return jsonify({"user": user.to_dict(), "token": issue_token(user)}), 201


@app.post("/api/auth/login")
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({"error": "Wrong email or password."}), 401

    return jsonify({"user": user.to_dict(), "token": issue_token(user)})


@app.get("/api/auth/me")
def me():
    if not current_user.is_authenticated:
        return jsonify(None)
    return jsonify(current_user.to_dict())


@app.patch("/api/auth/me")
@login_required
def update_me():
    """The site sends its full copy of the account plus `_seq`, an always-
    increasing number. Saves can arrive out of order (they're sent without
    waiting, so they survive the page changing), so an older one that turns up
    late is ignored instead of overwriting newer data."""
    data = request.get_json(silent=True) or {}
    seq = data.pop("_seq", None)
    last = (current_user.profile or {}).get("_seq") or 0
    if isinstance(seq, (int, float)) and seq <= last:
        return jsonify(current_user.to_dict())
    current_user.apply_patch(data)
    if isinstance(seq, (int, float)):
        current_user.profile = {**current_user.profile, "_seq": seq}
    db.session.commit()
    return jsonify(current_user.to_dict())


# --- bootstrap: everything a page needs, in one request ----------------------

@app.get("/api/bootstrap")
def bootstrap():
    warm_photo_search()
    user = current_user if current_user.is_authenticated else None
    data = {
        "categories": [c.to_dict() for c in Category.query.order_by(Category.sort, Category.name).all()],
        "products": [p.to_dict() for p in Product.query.order_by(Product.sort, Product.id).all()],
        "user": user.to_dict() if user else None,
    }
    if user and user.role == "admin":
        data["users"] = [u.to_dict() for u in User.query.order_by(User.created_at).all()]
    return jsonify(data)


# --- admin: catalogue and accounts -----------------------------------------

@app.patch("/api/admin/users/<user_id>")
@admin_required
def admin_update_user(user_id):
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found."}), 404
    user.apply_patch(request.get_json(silent=True) or {})
    db.session.commit()
    return jsonify(user.to_dict())


@app.put("/api/admin/categories/<cat_id>")
@admin_required
def admin_save_category(cat_id):
    d = request.get_json(silent=True) or {}
    name = str(d.get("name") or "").strip()
    if not name:
        return jsonify({"error": "Enter a category name."}), 400
    cat = db.session.get(Category, cat_id)
    if not cat:
        last = db.session.query(db.func.max(Category.sort)).scalar() or 0
        cat = Category(id=cat_id[:40], sort=last + 1)
        db.session.add(cat)
    cat.name = name[:120]
    cat.icon = d.get("icon") or "box"
    cat.hue = int(d.get("hue") or 0)
    cat.img = d.get("img") or ""
    db.session.commit()
    return jsonify(cat.to_dict())


@app.delete("/api/admin/categories/<cat_id>")
@admin_required
def admin_delete_category(cat_id):
    if Product.query.filter_by(cat_id=cat_id).first():
        return jsonify({"error": "Move or delete the products in this category first."}), 409
    cat = db.session.get(Category, cat_id)
    if cat:
        db.session.delete(cat)
        db.session.commit()
    return jsonify({"ok": True})


@app.put("/api/admin/products/<product_id>")
@admin_required
def admin_save_product(product_id):
    d = request.get_json(silent=True) or {}
    if not db.session.get(Category, d.get("cat")):
        return jsonify({"error": "Pick a category that exists."}), 400
    product = db.session.get(Product, product_id)
    if not product:
        # New products show first, like the site's own list does.
        first = db.session.query(db.func.min(Product.sort)).scalar() or 0
        product = Product(id=product_id[:40], sort=first - 1)
        db.session.add(product)
    product.apply(d)
    if not product.name or not product.price or product.price < 1:
        db.session.rollback()
        return jsonify({"error": "A product needs a name and a price above zero."}), 400
    db.session.commit()
    return jsonify(product.to_dict())


@app.delete("/api/admin/products/<product_id>")
@admin_required
def admin_delete_product(product_id):
    product = db.session.get(Product, product_id)
    if not product:
        return jsonify({"ok": True})
    if OrderItem.query.filter_by(product_id=product_id).first():
        return jsonify({"error": "This product is in past orders, so it can't be deleted. Set its stock to 0 instead."}), 409
    Review.query.filter_by(product_id=product_id).delete()
    db.session.delete(product)
    db.session.commit()
    return jsonify({"ok": True})


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
    """Body: { items: [{ productId, qty, custom? }], address: {...}, pay: "delivery" }
    Prices are worked out here, never taken from the request: business buyers
    get the bulk tiers and must meet each item's minimum, same rules as the
    site's Store.unitPrice / bulkMin. Used by the mobile app; the website still
    keeps its orders in the browser for now.

    Only pay-on-delivery is accepted: wallet balances aren't on the server yet,
    so a "wallet" order couldn't actually be charged."""
    data = request.get_json(silent=True) or {}
    items = data.get("items") or []
    address = data.get("address") or {}
    if data.get("pay", "delivery") != "delivery":
        return jsonify({"error": "Only pay on delivery is available here for now."}), 400
    if not items:
        return jsonify({"error": "Your cart is empty."}), 400

    business = current_user.mode == "business"
    wanted = {}
    custom = {}  # product id -> AiStudio design (logo, colour, notes) for that line
    for line in items:
        pid = line.get("productId")
        try:
            qty = int(line.get("qty") or 0)
        except (TypeError, ValueError):
            qty = 0
        if not pid or qty < 1:
            return jsonify({"error": "One of the items in your order is invalid."}), 400
        wanted[pid] = wanted.get(pid, 0) + qty
        if isinstance(line.get("custom"), dict) and pid not in custom:
            c = line["custom"]
            design = {
                "logo": str(c.get("logo") or "")[:600_000],  # a data: URL of the logo, kept small by the app
                "preview": str(c.get("preview") or "")[:400_000],
                "tint": str(c.get("tint") or "")[:20],
                "notes": str(c.get("notes") or "")[:400],
            }
            if any(design.values()):
                custom[pid] = design

    order_items = []
    subtotal = 0
    for pid, qty in wanted.items():
        product = db.session.get(Product, pid, with_for_update=True)
        if not product:
            return jsonify({"error": "One of the items in your order is no longer sold."}), 400
        if qty > product.stock:
            return jsonify({"error": f'Only {product.stock} left of "{product.name}".'}), 400
        minimum = (product.bulk_min or BULK_MIN_QTY) if business else 1
        if qty < minimum:
            return jsonify({"error": f'Business orders need at least {minimum} of "{product.name}".'}), 400
        off = max([t["off"] for t in BULK_TIERS if qty >= t["from"]], default=0) if business else 0
        # floor(x + 0.5) rounds halves up like the site's Math.round and Dart's
        # round(); Python's round() would send 28.5 to 28 and disagree by ₦1.
        unit = math.floor(product.price * (1 - off / 100) + 0.5)
        order_items.append(OrderItem(product_id=product.id, name=product.name, price=unit, qty=qty, custom=custom.get(pid)))
        subtotal += unit * qty
        product.stock -= qty
        product.sold = (product.sold or 0) + qty

    delivery_fee = 0 if subtotal >= FREE_SHIPPING_FROM else SHIPPING_FEE
    total = subtotal + delivery_fee

    order = Order(id="ORD-" + uuid.uuid4().hex[:6].upper(), user_id=current_user.id, mode=current_user.mode,
                  status="Order placed", stage=0, subtotal=subtotal, delivery_fee=delivery_fee, total=total,
                  address=address, pay="delivery", tracking=[{"stage": 0, "at": now().isoformat()}], items=order_items)
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
# 7b. Search by photo - backs the camera button in the app's search bar.
# Works with no API key. Every product photo (main and gallery) gets a
# fingerprint of its colours (hue/saturation/brightness, centre-weighted,
# background ignored, whatever its colour) and its shape (edge directions in each quarter of
# the picture). A product scores by its best-matching photo, and products in
# the same category as the top matches get a nudge, so "similar items" stay
# on topic. With OPENAI_API_KEY set, a vision model also names the item and
# its category, which outweighs the picture match.
# Measured on 61 held-out product photos: right product first 46/61, in the
# top 3 56/61 (colour alone on the main photo managed 39 and 50).
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent  # product photos live in ../assets
PHOTO_MAX_BYTES = 8 * 1024 * 1024
_fingerprints = {}  # photo src -> fingerprint (or None if unreadable), built on first use
CATEGORY_NUDGE = 0.15


def _open_image(src):
    """A PIL image from a data: URL, an http(s) URL or a path under the site root."""
    import base64
    import io
    from PIL import Image

    if src.startswith("data:"):
        raw = base64.b64decode(src.split(",", 1)[1])
    elif src.startswith("http"):
        raw = requests.get(src, timeout=8).content
    else:
        path = (REPO_ROOT / src).resolve()
        if REPO_ROOT not in path.parents:
            raise ValueError("image path outside the site")
        raw = path.read_bytes()
    return Image.open(io.BytesIO(raw))


def _fingerprint(img):
    """{"colour": 12x3x3 HSV histogram, "shape": 2x2 cells x 8 edge directions},
    both normalised. The background is whatever colour fills the border of the
    picture (studio white, a table, a wall); pixels close to it barely count
    towards colour and make no edges, so only the item itself is compared."""
    import math
    from collections import Counter
    from PIL import Image

    img.draft("RGB", (160, 160))  # JPEGs decode straight at low resolution
    img.thumbnail((160, 160), Image.Resampling.BILINEAR, reducing_gap=2.0)
    img = img.convert("RGBA")
    flat = Image.new("RGBA", img.size, (255, 255, 255, 255))
    flat.alpha_composite(img)

    small = flat.convert("RGB").resize((48, 48), Image.Resampling.BILINEAR)
    rgb_px = small.load()
    border = [rgb_px[x, y] for x in range(48) for y in (0, 1, 46, 47)] + [rgb_px[x, y] for y in range(48) for x in (0, 1, 46, 47)]
    common = Counter((r // 24, g // 24, b // 24) for r, g, b in border).most_common(1)[0][0]
    near = [c for c in border if (c[0] // 24, c[1] // 24, c[2] // 24) == common]
    bg = tuple(sum(c[i] for c in near) / len(near) for i in range(3))
    # Only call it background if most of the border agrees; otherwise the item fills the frame.
    has_bg = len(near) >= len(border) * 0.35

    def is_bg(c):
        return has_bg and abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) < 70

    hsv_px = small.convert("HSV").load()
    colour = [0.0] * (12 * 3 * 3)
    for y in range(48):
        for x in range(48):
            h, s, v = hsv_px[x, y]
            dx, dy = (x - 23.5) / 24, (y - 23.5) / 24
            w = max(0.05, 1 - (dx * dx + dy * dy) * 0.6)
            if is_bg(rgb_px[x, y]):
                w *= 0.04
            # Greys have no meaningful hue: put them in hue bin 0 with low saturation.
            hb = 0 if s < 40 else min(11, h * 12 // 256)
            colour[(hb * 3 + min(2, s * 3 // 256)) * 3 + min(2, v * 3 // 256)] += w

    n = 64
    mid = flat.convert("RGB").resize((n, n), Image.Resampling.BILINEAR)
    mid_px = mid.load()
    grey = mid.convert("L").load()
    shape = [0.0] * 32
    for y in range(1, n - 1):
        for x in range(1, n - 1):
            if is_bg(mid_px[x, y]) and is_bg(mid_px[x + 1, y]) and is_bg(mid_px[x, y + 1]):
                continue  # texture in the background (wood grain, cloth) isn't the item
            gx = grey[x + 1, y] - grey[x - 1, y]
            gy = grey[x, y + 1] - grey[x, y - 1]
            mag = math.hypot(gx, gy)
            if mag < 8:
                continue
            direction = int(((math.atan2(gy, gx) + math.pi) % math.pi) / math.pi * 8) % 8
            cell = (2 if y >= n // 2 else 0) + (1 if x >= n // 2 else 0)
            shape[cell * 8 + direction] += mag

    def norm(v):
        total = sum(v) or 1
        return [x / total for x in v]

    return {"colour": norm(colour), "shape": norm(shape)}


def _similarity(a, b):
    """0..1, by histogram overlap: colour counts a bit more than shape."""
    overlap = lambda u, v: sum(min(x, y) for x, y in zip(u, v))
    return overlap(a["colour"], b["colour"]) * 0.55 + overlap(a["shape"], b["shape"]) * 0.45


def _photo_fingerprint(src):
    if src not in _fingerprints:
        try:
            _fingerprints[src] = _fingerprint(_open_image(src))
        except Exception:  # missing or unreadable photo: leave it out of matching
            _fingerprints[src] = None
    return _fingerprints[src]


def _product_fingerprints(p):
    """Fingerprints of every photo of a product, so any angle can match."""
    srcs = dict.fromkeys(s for s in [p.img, *(p.imgs or [])] if s)  # unique, in order
    return [fp for fp in (_photo_fingerprint(s) for s in srcs) if fp]


_warm_started = False


def warm_photo_search():
    """Fingerprint every product photo in the background, once per process, so
    the first photo search doesn't wait for all of them. Started from the first
    page load rather than at import: gunicorn's preload forks after import, and
    a thread started before the fork wouldn't survive into the worker."""
    global _warm_started
    if _warm_started:
        return
    _warm_started = True

    def run():
        with app.app_context():
            try:
                for p in Product.query.all():
                    _product_fingerprints(p)
            except Exception:
                pass  # Pillow missing etc.; the search route reports it properly

    import threading
    threading.Thread(target=run, daemon=True).start()


def _describe_photo(data_url, categories):
    """Ask a vision model what the item is. Returns {label, category, keywords} or None."""
    if not OPENAI_API_KEY:
        return None
    cats = ", ".join(f"{c.id} ({c.name})" for c in categories)
    try:
        res = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {OPENAI_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": "gpt-4o-mini",
                "response_format": {"type": "json_object"},
                "max_tokens": 150,
                "messages": [{"role": "user", "content": [
                    {"type": "text", "text": (
                        "What product is in this photo? Reply as JSON: "
                        '{"label": short name, "category": one id from this list or null, '
                        '"keywords": up to 6 lowercase words a shop listing would use}. '
                        f"Categories: {cats}")},
                    {"type": "image_url", "image_url": {"url": data_url, "detail": "low"}},
                ]}],
            },
            timeout=30,
        )
        res.raise_for_status()
        out = json.loads(res.json()["choices"][0]["message"]["content"])
        return out if isinstance(out, dict) else None
    except (requests.RequestException, ValueError, KeyError, IndexError):
        return None  # fall back to picture matching alone


@app.post("/api/search/photo")
def search_by_photo():
    data = request.get_json(silent=True) or {}
    image = data.get("image") or ""
    limit = min(int(data.get("limit") or 24), 60)
    if not image.startswith("data:image/"):
        return jsonify({"error": "Send the photo as a data:image/... URL."}), 400
    if len(image) > PHOTO_MAX_BYTES * 4 // 3:
        return jsonify({"error": "That photo is too large. Try one under 8 MB."}), 413

    try:
        target = _fingerprint(_open_image(image))
    except ImportError:
        return jsonify({"error": "Photo search needs Pillow on the server (pip install -r requirements.txt)."}), 503
    except Exception:
        return jsonify({"error": "Couldn't read that photo. Try a JPG or PNG."}), 400

    products = Product.query.order_by(Product.sort).all()
    ai = _describe_photo(image, Category.query.order_by(Category.sort).all())
    keywords = [str(k).lower() for k in (ai or {}).get("keywords", []) if str(k).strip()][:6]

    # How much each product looks like the photo: its best-matching picture.
    looks = {p.id: max((_similarity(target, fp) for fp in _product_fingerprints(p)), default=0.0) for p in products}

    # Nudge towards the categories the closest matches come from.
    top = sorted(products, key=lambda p: looks[p.id], reverse=True)[:6]
    votes = {}
    for p in top:
        votes[p.cat_id] = votes.get(p.cat_id, 0) + looks[p.id]
    total_votes = sum(votes.values()) or 1

    scored = []
    for p in products:
        score = looks[p.id] + CATEGORY_NUDGE * votes.get(p.cat_id, 0) / total_votes
        if ai:
            text = f"{p.name} {p.sub or ''} {p.desc}".lower()
            score = looks[p.id] * 0.4
            score += 0.6 if ai.get("category") == p.cat_id else 0
            score += min(0.6, 0.15 * sum(1 for k in keywords if k in text))
        scored.append((score, p.sold or 0, p))
    scored.sort(key=lambda t: (t[0], t[1]), reverse=True)

    return jsonify({
        "label": (ai or {}).get("label"),
        "smart": ai is not None,
        "products": [p.to_dict() for _, _, p in scored[:limit]],
    })


# ---------------------------------------------------------------------------
# 8. Seed command - loads seed_data.json (exported from ../js/data.js) into
# the database. Safe to re-run: upserts by id rather than duplicating rows.
#     flask --app app.py seed
# ---------------------------------------------------------------------------

SEED_PATH = Path(__file__).parent / "seed_data.json"


def seed_database():
    with open(SEED_PATH, encoding="utf-8") as f:
        data = json.load(f)

    for i, row in enumerate(data["categories"]):
        db.session.merge(Category(id=row["id"], name=row["name"], icon=row["icon"], hue=row["hue"],
                                  img=row["img"], sort=i))

    for row in data["business_types"]:
        db.session.merge(BusinessType(id=row["id"], name=row["name"], cats=row["cats"]))

    for row in data["agents"]:
        db.session.merge(Agent(id=row["id"], name=row["name"], phone=row["phone"], whatsapp=row["whatsapp"]))

    for i, row in enumerate(data["products"]):
        db.session.merge(Product(
            id=row["id"], cat_id=row["cat"], sub=row.get("sub"), name=row["name"],
            price=row["price"], old_price=row.get("oldPrice", 0), rating=row.get("rating", 0),
            sold=row.get("sold", 0), stock=row.get("stock", 0), ship=row.get("ship", "7-15"),
            condition=row.get("condition", "new"), bulk_min=row.get("bulkMin"),
            img=row.get("img", ""), imgs=row.get("imgs", []), gif=row.get("gif", ""),
            desc=row.get("desc", ""), sort=i,
        ))

    # The admin's password is never the public demo one from seed_data.json:
    # it comes from ADMIN_PASSWORD, or is generated and printed to the log once.
    admin = data["demo_admin"]
    if not db.session.get(User, "u_admin"):
        password = os.environ.get("ADMIN_PASSWORD") or secrets.token_urlsafe(12)
        user = User(id="u_admin", name=admin["name"], email=admin["email"], phone=admin["phone"],
                    role="admin", profile={})
        user.set_password(password)
        user.apply_patch({"mode": "personal", "favs": []})
        db.session.add(user)
        if not os.environ.get("ADMIN_PASSWORD"):
            print(f"Created admin {admin['email']} with generated password: {password}", flush=True)

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
