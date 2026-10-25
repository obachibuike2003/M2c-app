import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';

/// Everything the screens read: the catalogue and account from the backend,
/// plus the cart, which (like on the website) is kept on this device.
class AppState extends ChangeNotifier {
  final api = Api();
  late SharedPreferences _prefs;

  List<Category> categories = [];
  List<Product> products = [];
  List<Product> recommended = [];
  User? user;
  List<CartLine> cart = [];

  bool loading = true;
  String? loadError;

  Product? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Category? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool get isBusiness => user?.isBusiness ?? false;

  // ---------------------------------------------------------------- loading

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    api.token = _prefs.getString('token');
    final saved = _prefs.getString('cart');
    if (saved != null) {
      cart = (jsonDecode(saved) as List).map((e) => CartLine.fromJson(e as Map<String, dynamic>)).toList();
    }
    await refresh();
  }

  /// Same call the website makes on every page: catalogue + signed-in account.
  Future<void> refresh() async {
    loading = categories.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      final data = await api.get('/api/bootstrap') as Map<String, dynamic>;
      categories = (data['categories'] as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      products = (data['products'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      if (data['user'] != null) {
        user = User(Map<String, dynamic>.from(data['user'] as Map));
      } else {
        await _clearLogin(); // signed out, or the saved login expired
      }
      await _loadRecommended();
    } on ApiException catch (e) {
      loadError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// The backend's recommendation algorithm (business type, favourites and
  /// past orders weigh in; best-sellers break ties).
  Future<void> _loadRecommended() async {
    try {
      final list = await api.get('/api/recommendations?limit=12') as List;
      recommended = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      recommended = [...products]..sort((a, b) => b.sold.compareTo(a.sold));
      recommended = recommended.take(12).toList();
    }
  }

  // ---------------------------------------------------------------- account

  Future<void> login(String email, String password) async {
    final data = await api.post('/api/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    await _saveLogin(data);
  }

  Future<void> signup({required String name, required String phone, required String email, required String password}) async {
    final data = await api.post('/api/auth/signup', {
      'name': name, 'phone': phone, 'whatsapp': phone, 'email': email, 'password': password,
      'profile': {'mode': 'personal', 'favs': <String>[]},
    }) as Map<String, dynamic>;
    await _saveLogin(data);
  }

  Future<void> _saveLogin(Map<String, dynamic> data) async {
    api.token = data['token'] as String;
    await _prefs.setString('token', api.token!);
    user = User(Map<String, dynamic>.from(data['user'] as Map));
    await _loadRecommended();
    notifyListeners();
  }

  Future<void> logout() async {
    await _clearLogin();
    await _loadRecommended();
    notifyListeners();
  }

  Future<void> _clearLogin() async {
    api.token = null;
    user = null;
    await _prefs.remove('token');
  }

  /// Saves account fields to the server. `_seq` always rises, so the server
  /// ignores an older save that arrives after a newer one (same as the site).
  Future<void> updateAccount(Map<String, dynamic> patch) async {
    if (user == null) return;
    final before = Map<String, dynamic>.from(user!.raw);
    user = User({...user!.raw, ...patch});
    notifyListeners();
    try {
      final saved = await api.patch('/api/auth/me', {...patch, '_seq': DateTime.now().microsecondsSinceEpoch});
      user = User(Map<String, dynamic>.from(saved as Map));
      notifyListeners();
    } catch (e) {
      user = User(before); // put it back so the screen shows what's really saved
      notifyListeners();
      rethrow;
    }
  }

  bool isFav(String productId) => user?.favs.contains(productId) ?? false;

  Future<void> toggleFav(String productId) {
    final favs = {...?user?.favs};
    if (!favs.remove(productId)) favs.add(productId);
    return updateAccount({'favs': favs.toList()});
  }

  Future<void> setBusiness(String name, String type) =>
      updateAccount({'mode': 'business', 'business': {'name': name.trim(), 'type': type}});

  Future<void> setPersonal() => updateAccount({'mode': 'personal'});

  // ---------------------------------------------------------------- pricing

  /// Percent off for this many pieces of one item (business buyers only).
  int bulkOff(int qty) {
    var best = 0;
    for (final t in AppConfig.bulkTiers) {
      if (qty >= t.from && t.off > best) best = t.off;
    }
    return best;
  }

  int unitPrice(Product p, int qty) => isBusiness ? (p.price * (1 - bulkOff(qty) / 100)).round() : p.price;

  int minQty(Product p) => isBusiness ? p.businessMin : 1;

  // ---------------------------------------------------------------- cart

  int get cartCount => cart.fold(0, (n, l) => n + l.qty);

  Future<void> _saveCart() => _prefs.setString('cart', jsonEncode(cart.map((l) => l.toJson()).toList()));

  /// Adds to the cart; returns an error message, or null if it worked.
  String? addToCart(Product p, int qty) {
    if (p.stock < 1) return 'This item is out of stock.';
    final i = cart.indexWhere((l) => l.productId == p.id);
    final inCart = i == -1 ? 0 : cart[i].qty;
    if (inCart + qty > p.stock) return 'Only ${p.stock} left in stock.';
    if (i == -1) {
      cart.add(CartLine(p.id, qty));
    } else {
      cart[i].qty += qty;
    }
    _saveCart();
    notifyListeners();
    return null;
  }

  void setQty(String productId, int qty) {
    final p = product(productId);
    if (qty < 1 || p == null) {
      cart.removeWhere((l) => l.productId == productId);
    } else {
      cart.firstWhere((l) => l.productId == productId).qty = qty.clamp(1, p.stock);
    }
    _saveCart();
    notifyListeners();
  }

  /// Cart lines joined with their products; lines whose product is gone are skipped.
  List<({Product product, int qty, int unit, int total, bool short})> get cartLines => [
        for (final l in cart)
          if (product(l.productId) case final p?)
            (product: p, qty: l.qty, unit: unitPrice(p, l.qty), total: unitPrice(p, l.qty) * l.qty, short: l.qty < minQty(p)),
      ];

  int get subtotal => cartLines.fold(0, (n, l) => n + l.total);
  int get shipping => subtotal == 0 || subtotal >= AppConfig.freeShippingFrom ? 0 : AppConfig.shippingFee;
  int get total => subtotal + shipping;

  // ---------------------------------------------------------------- orders

  /// Places the order on the server, then empties the cart. Pay on delivery.
  Future<Order> placeOrder(Map<String, String> address) async {
    final data = await api.post('/api/orders', {
      'items': [for (final l in cart) {'productId': l.productId, 'qty': l.qty}],
      'address': address,
      'pay': 'delivery',
    });
    cart = [];
    await _saveCart();
    await updateAccount({'address': address}).catchError((_) {});
    await refresh(); // stock and "sold" counts changed
    return Order(Map<String, dynamic>.from(data as Map));
  }

  Future<List<Order>> myOrders() async {
    final list = await api.get('/api/orders') as List;
    return list.map((e) => Order(Map<String, dynamic>.from(e as Map))).toList();
  }
}
