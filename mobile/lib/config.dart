/// Where the app talks to, and the shop rules it shares with the website
/// (kept in step with js/config.js and backend/app.py).
class AppConfig {
  /// The Flask backend (backend/app.py). Override when testing against a local
  /// server: flutter run --dart-define=API_BASE=http://127.0.0.1:5000
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://api.eazy2buychina.com');

  /// Where the product photos (assets/products/...) are served from: the
  /// website (eazy2buychina.com) by default. The hosted web app sets this to '' and serves the
  /// photos itself, from the same address, so the browser lets the app draw
  /// on them (AiStudio colours and previews).
  static const siteBase = String.fromEnvironment('SITE_BASE', defaultValue: 'https://eazy2buychina.com');

  static const appName = 'Easy2buy';

  /// When this build was made, shown on the Account screen so you can tell
  /// which version a phone is running. Set by the deploy script.
  static const build = String.fromEnvironment('BUILD', defaultValue: 'dev');
  static const tagline = 'Shop China. Pay in Naira.';
  static const supportEmail = 'support@example.com';
  static const supportWhatsapp = '+234 800 000 0000';

  /// Referral reward each side gets; the server's REFERRAL_REWARD is what's actually paid.
  static const referralReward = 1000;

  /// Where invite links send people (the hosted app).
  static const appUrl = 'https://app.eazy2buychina.com';

  static const shippingFee = 2500;
  static const freeShippingFrom = 50000;

  /// Business (bulk) buying: minimum pieces per item, and percent off by quantity.
  static const bulkMinQty = 10;
  static const bulkTiers = [(from: 10, off: 5), (from: 50, off: 10), (from: 100, off: 15)];

  /// Exchange rates in naira per 1 unit, the website's SEED_RATES (js/data.js).
  /// "buy" is what a customer pays, "sell" is what they receive. Demo rates.
  static const rates = [
    (code: 'CNY', name: 'Chinese Yuan (RMB)', crypto: false, dp: 2, buy: 219.0, sell: 213.0),
    (code: 'USDT', name: 'Tether', crypto: true, dp: 2, buy: 1560.0, sell: 1535.0),
    (code: 'USDC', name: 'USD Coin', crypto: true, dp: 2, buy: 1558.0, sell: 1533.0),
    (code: 'BTC', name: 'Bitcoin', crypto: true, dp: 8, buy: 165000000.0, sell: 162500000.0),
    (code: 'ETH', name: 'Ethereum', crypto: true, dp: 6, buy: 5900000.0, sell: 5800000.0),
    (code: 'BNB', name: 'BNB', crypto: true, dp: 5, buy: 1050000.0, sell: 1030000.0),
    (code: 'SOL', name: 'Solana', crypto: true, dp: 4, buy: 310000.0, sell: 304000.0),
    (code: 'TRX', name: 'TRON', crypto: true, dp: 2, buy: 420.0, sell: 410.0),
  ];

  static const trackStages = [
    'Order placed', 'Confirmed', 'Bought from supplier', 'Shipped from China',
    'Arrived in Nigeria', 'At our Lagos warehouse', 'Out for delivery', 'Delivered',
  ];

  /// Business buyers' agents, the website's SEED_AGENTS (js/data.js).
  static const agents = [
    (id: 'a1', name: 'Amaka', whatsapp: '2348000000001'),
    (id: 'a2', name: 'Tunde', whatsapp: '2348000000002'),
  ];

  static const businessTypes = [
    (id: 'fashion', name: 'Fashion & clothing store'),
    (id: 'phones', name: 'Phone & gadget shop'),
    (id: 'electronics', name: 'Electronics shop'),
    (id: 'beauty', name: 'Beauty, salon & aesthetics'),
    (id: 'soap', name: 'Soap, detergent & cosmetics making'),
    (id: 'packaging', name: 'Plastic & packaging production'),
    (id: 'furniture', name: 'Furniture & interior'),
    (id: 'home', name: 'Home & kitchen store'),
    (id: 'supermarket', name: 'Supermarket & provisions'),
    (id: 'sports', name: 'Sports & fitness'),
    (id: 'cars', name: 'Car & bike dealer'),
    (id: 'other', name: 'Something else'),
  ];
}
