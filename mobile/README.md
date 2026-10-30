# Eazy2buy mobile app

The Flutter (Dart) version of the Eazy2buy storefront. It talks to the same
Flask backend as the website (`../backend/app.py`), so accounts, products and
orders are shared between the app and the site.

## What's in it

- Splash, then a first-launch walkthrough (Skip / Next / Get started) ending in
  Create account, Sign in, or Continue as guest
- Home: search, hero slider, perks, business card, category bubbles, recommended
  products with category chips
- Shop: all categories, product lists with subcategory and condition filters,
  sorting and search
- Product page with photo gallery, retail and wholesale (bulk) pricing, related items
- Cart, checkout (pay on delivery), order tracking timeline
- Account: personal / business buying, saved products, sign out

## Run it

```sh
flutter pub get
flutter run                      # uses the live API, https://m2c.13-48-31-7.sslip.io
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:5000   # against a local backend
```

For a local backend, allow the Flutter web origin in CORS, e.g.
`CORS_ORIGINS=http://localhost:8090` when serving `build/web` on port 8090.

## Build an Android APK

Needs the Android SDK and a JDK (`flutter doctor` lists what's missing):

```sh
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`.

## Layout

| File | What it does |
| --- | --- |
| `lib/config.dart` | API address, shop rules (shipping, bulk tiers), order stages |
| `lib/api.dart` | HTTP client with the bearer-token login |
| `lib/app_state.dart` | Catalogue, account, cart and orders (Provider) |
| `lib/theme.dart` | Brand colours, fonts and Material theme |
| `lib/widgets.dart` | Shared pieces: product card and grid, images, motion helpers |
| `lib/screens/` | One file per area: onboarding, home, shop, product, cart, orders, auth, account |
