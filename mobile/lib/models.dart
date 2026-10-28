import 'config.dart';

/// Shapes match what backend/app.py's to_dict() methods return.

class Category {
  final String id, name, icon, img;
  final int hue;

  Category({required this.id, required this.name, required this.icon, required this.hue, required this.img});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: (j['icon'] ?? 'box') as String,
        hue: (j['hue'] ?? 220) as int,
        img: (j['img'] ?? '') as String,
      );
}

class Product {
  final String id, cat, name, ship, condition, desc, img, gif;
  final String? sub;
  final int price, oldPrice, sold, stock;
  final int? bulkMin;
  final double rating;
  final List<String> imgs;

  Product({
    required this.id, required this.cat, required this.sub, required this.name,
    required this.price, required this.oldPrice, required this.rating, required this.sold,
    required this.stock, required this.ship, required this.condition, required this.bulkMin,
    required this.img, required this.imgs, required this.gif, required this.desc,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        cat: j['cat'] as String,
        sub: j['sub'] as String?,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        oldPrice: ((j['oldPrice'] ?? 0) as num).toInt(),
        rating: ((j['rating'] ?? 0) as num).toDouble(),
        sold: ((j['sold'] ?? 0) as num).toInt(),
        stock: ((j['stock'] ?? 0) as num).toInt(),
        ship: (j['ship'] ?? '7-15') as String,
        condition: (j['condition'] ?? 'new') as String,
        bulkMin: (j['bulkMin'] as num?)?.toInt(),
        img: (j['img'] ?? '') as String,
        imgs: ((j['imgs'] ?? []) as List).cast<String>(),
        gif: (j['gif'] ?? '') as String,
        desc: (j['desc'] ?? '') as String,
      );

  bool get used => condition == 'used';
  int get discount => oldPrice > price ? ((1 - price / oldPrice) * 100).round() : 0;

  /// Every photo, main one first, without duplicates or blanks.
  List<String> get photos => {img, ...imgs}.where((s) => s.isNotEmpty).toList();

  /// Smallest order a business buyer may place for this item.
  int get businessMin => (bulkMin != null && bulkMin! > 0) ? bulkMin! : AppConfig.bulkMinQty;
}

class User {
  final Map<String, dynamic> raw;
  User(this.raw);

  String get id => raw['id'] as String;
  String get name => (raw['name'] ?? '') as String;
  String get firstName => name.split(' ').first;
  String get email => (raw['email'] ?? '') as String;
  String get phone => (raw['phone'] ?? '') as String;
  String get role => (raw['role'] ?? 'customer') as String;
  bool get isBusiness => raw['mode'] == 'business';
  Map<String, dynamic>? get business => raw['business'] as Map<String, dynamic>?;
  List<String> get favs => ((raw['favs'] ?? []) as List).cast<String>();
  Map<String, dynamic>? get address => raw['address'] as Map<String, dynamic>?;
  Map<String, dynamic> get brand => ((raw['brand'] as Map?) ?? const {}).cast<String, dynamic>();

  /// Identity check: none, pending, verified or rejected.
  String get verifyStatus => ((raw['verify'] as Map?)?['status'] ?? 'none') as String;
}

class CartLine {
  final String productId;
  int qty;

  /// An AiStudio design for this line (logo, preview, tint, notes), or null.
  Map<String, dynamic>? custom;
  CartLine(this.productId, this.qty, {this.custom});

  Map<String, dynamic> toJson() => {'id': productId, 'qty': qty, if (custom != null) 'custom': custom};
  factory CartLine.fromJson(Map<String, dynamic> j) =>
      CartLine(j['id'] as String, (j['qty'] as num).toInt(), custom: (j['custom'] as Map?)?.cast<String, dynamic>());
}

class Order {
  final Map<String, dynamic> raw;
  Order(this.raw);

  String get id => raw['id'] as String;
  String get status => (raw['status'] ?? '') as String;
  int get stage => ((raw['stage'] ?? 0) as num).toInt();
  int get total => ((raw['total'] ?? 0) as num).toInt();
  DateTime? get createdAt => raw['createdAt'] == null ? null : DateTime.tryParse(raw['createdAt'] as String);
  List<Map<String, dynamic>> get items => ((raw['items'] ?? []) as List).cast<Map<String, dynamic>>();
}
