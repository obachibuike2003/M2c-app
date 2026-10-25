/// Where the app talks to, and the shop rules it shares with the website
/// (kept in step with js/config.js and backend/app.py).
class AppConfig {
  /// The Flask backend (backend/app.py). Override when testing against a local
  /// server: flutter run --dart-define=API_BASE=http://127.0.0.1:5000
  static const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://m2c.13-48-31-7.sslip.io');

  /// The static website, which hosts the product photos (assets/products/...).
  static const siteBase = 'https://m2c-app-vqeb.onrender.com';

  static const appName = 'Easy2buy';
  static const tagline = 'Shop China. Pay in Naira.';
  static const supportEmail = 'support@example.com';
  static const supportWhatsapp = '+234 800 000 0000';

  static const shippingFee = 2500;
  static const freeShippingFrom = 50000;

  /// Business (bulk) buying: minimum pieces per item, and percent off by quantity.
  static const bulkMinQty = 10;
  static const bulkTiers = [(from: 10, off: 5), (from: 50, off: 10), (from: 100, off: 15)];

  static const trackStages = [
    'Order placed', 'Confirmed', 'Bought from supplier', 'Shipped from China',
    'Arrived in Nigeria', 'At our Lagos warehouse', 'Out for delivery', 'Delivered',
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
