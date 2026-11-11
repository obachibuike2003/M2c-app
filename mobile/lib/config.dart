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

  static const appName = 'Eazy2buy';

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

  /// Every order's journey, in order. Same as TRACK_STAGES on the server and
  /// the website (js/data.js); the team moves each order along from the admin page.
  static const trackStages = [
    (name: 'Order placed', text: 'We have your order.'),
    (name: 'Payment confirmed', text: 'Your payment is in and we are processing your order.'),
    (name: 'Factory paid', text: 'We have paid the factory for your goods.'),
    (name: 'Goods being prepared', text: 'The factory is getting your products ready.'),
    (name: 'At the shipping company', text: 'Your goods are with our shipping company in China.'),
    (name: 'Checked by our agent', text: 'Our agent has checked that everything is in order.'),
    (name: 'Shipped to Nigeria', text: 'Your goods are on their way to Nigeria.'),
    (name: 'At our Nigeria warehouse', text: 'Your goods have arrived at the shipping company\'s warehouse in Nigeria.'),
    (name: 'On the way to your state', text: 'Your goods are on their way to your state.'),
    (name: 'Delivered', text: 'You have your goods. Enjoy!'),
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
