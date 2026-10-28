import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, Uint8List;
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

  /// Switches to business buying. Like the website, a business buyer gets an
  /// agent; the app can't see other customers to find the least busy one, so
  /// it spreads people evenly by account id instead.
  Future<void> setBusiness(String name, String type) {
    final agents = AppConfig.agents;
    final current = user?.raw['agentId'] as String?;
    final keep = agents.any((a) => a.id == current);
    final spread = (user?.id ?? '').codeUnits.fold<int>(0, (a, b) => a + b) % agents.length;
    return updateAccount({
      'mode': 'business',
      'business': {'name': name.trim(), 'type': type},
      'agentId': keep ? current : agents[spread].id,
    });
  }

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
  /// [custom] is an AiStudio design; it replaces any design already on that line.
  String? addToCart(Product p, int qty, {Map<String, dynamic>? custom}) {
    if (p.stock < 1) return 'This item is out of stock.';
    final i = cart.indexWhere((l) => l.productId == p.id);
    final inCart = i == -1 ? 0 : cart[i].qty;
    if (inCart + qty > p.stock) return 'Only ${p.stock} left in stock.';
    if (i == -1) {
      cart.add(CartLine(p.id, qty, custom: custom));
    } else {
      cart[i].qty += qty;
      if (custom != null) cart[i].custom = custom;
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
  List<({Product product, int qty, int unit, int total, bool short, Map<String, dynamic>? custom})> get cartLines => [
        for (final l in cart)
          if (product(l.productId) case final p?)
            (product: p, qty: l.qty, unit: unitPrice(p, l.qty), total: unitPrice(p, l.qty) * l.qty, short: l.qty < minQty(p), custom: l.custom),
      ];

  int get subtotal => cartLines.fold(0, (n, l) => n + l.total);
  int get shipping => subtotal == 0 || subtotal >= AppConfig.freeShippingFrom ? 0 : AppConfig.shippingFee;
  int get total => subtotal + shipping;

  // ---------------------------------------------------------------- orders

  /// Places the order on the server, then empties the cart. Pay on delivery.
  Future<Order> placeOrder(Map<String, String> address) async {
    final data = await api.post('/api/orders', {
      'items': [for (final l in cart) {'productId': l.productId, 'qty': l.qty, if (l.custom != null) 'custom': l.custom}],
      'address': address,
      'pay': 'delivery',
    });
    cart = [];
    await _saveCart();
    await updateAccount({'address': address}).catchError((_) {});
    await refresh(); // stock and "sold" counts changed
    return Order(Map<String, dynamic>.from(data as Map));
  }

  // ---------------------------------------------------------------- exchange

  /// Wallet balances per currency code, saved on the account like the website's.
  Map<String, num> get balances => {
        for (final e in ((user?.raw['balances'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num? ?? 0),
      };

  static int dpOf(String code) => code == 'NGN' ? 2 : AppConfig.rates.firstWhere((r) => r.code == code).dp;

  static double _floor(num n, int dp) {
    final f = 1.0 * _pow10(dp);
    return (n * f + 1e-9).floorToDouble() / f;
  }

  static num _pow10(int dp) => [for (var i = 0; i < dp; i++) 10].fold<num>(1, (a, b) => a * b);

  /// How much of [to] you get for [amount] of [from]; same maths as the site's Store.quote.
  double quote(String from, String to, num amount) {
    if (amount <= 0) return 0;
    if (from == 'NGN') {
      final r = AppConfig.rates.firstWhere((r) => r.code == to);
      return _floor(amount / r.buy, r.dp);
    }
    final r = AppConfig.rates.firstWhere((r) => r.code == from);
    return _floor(amount * r.sell, 2);
  }

  /// Swaps wallet money; returns how much arrived. Throws with a message the screen can show.
  Future<double> exchange(String from, String to, num amount) async {
    if (user == null) throw ApiException('Please sign in first.');
    final b = balances;
    if (!(amount > 0)) throw ApiException('Enter an amount.');
    if (amount > (b[from] ?? 0)) throw ApiException('You do not have enough $from in your wallet.');
    final got = quote(from, to, amount);
    if (!(got > 0)) throw ApiException('That amount is too small to exchange.');
    b[from] = _floor((b[from] ?? 0) - amount, dpOf(from));
    b[to] = _floor((b[to] ?? 0) + got, dpOf(to));
    await updateAccount({'balances': b});
    await _addTxn({'type': 'exchange', 'desc': 'Exchanged $from to $to', 'amount': -amount, 'currency': from, 'gotAmount': got, 'gotCurrency': to});
    return got;
  }

  // ---------------------------------------------------------------- wallet

  /// Wallet history. Like the website, it's kept on this device only.
  List<Map<String, dynamic>> get txns {
    if (user == null) return const [];
    final raw = _prefs.getString('txns_${user!.id}');
    return raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _addTxn(Map<String, dynamic> t) async {
    final list = [{'status': 'completed', 'createdAt': DateTime.now().millisecondsSinceEpoch, ...t}, ...txns];
    await _prefs.setString('txns_${user!.id}', jsonEncode(list.take(200).toList()));
  }

  /// Demo top-up, same limits as the website: the money appears instantly.
  Future<void> fundWallet(num amount) async {
    if (user == null) throw ApiException('Please sign in first.');
    if (!(amount >= 100)) throw ApiException('Enter at least ₦100.');
    if (amount > 10000000) throw ApiException('The demo limit is ₦10,000,000 per top-up.');
    final b = balances;
    b['NGN'] = _floor((b['NGN'] ?? 0) + amount, 2);
    await updateAccount({'balances': b});
    await _addTxn({'type': 'fund', 'desc': 'Wallet top-up (demo)', 'amount': amount, 'currency': 'NGN'});
    notifyListeners();
  }

  /// Sends money out of the wallet; it's held as "processing" until the store pays it.
  Future<void> requestPayout(String code, num amount, String destination) async {
    if (user == null) throw ApiException('Please sign in first.');
    final b = balances;
    if (!(amount > 0)) throw ApiException('Enter an amount.');
    if (amount > (b[code] ?? 0)) throw ApiException('You do not have enough $code.');
    if (destination.trim().isEmpty) throw ApiException('Enter where the money should go.');
    b[code] = _floor((b[code] ?? 0) - amount, dpOf(code));
    await updateAccount({'balances': b});
    await _addTxn({'type': 'payout', 'desc': 'Send to ${destination.trim()}', 'amount': -amount, 'currency': code, 'status': 'processing'});
    notifyListeners();
  }

  // ---------------------------------------------------------------- brand, identity

  Future<void> saveBrand(Map<String, dynamic> brand) => updateAccount({'brand': {...?user?.brand, ...brand}});

  /// Sends a selfie for the team to check, like the website's identity check.
  Future<void> submitVerification(String selfieDataUrl) =>
      updateAccount({'verify': {'status': 'pending', 'selfie': selfieDataUrl, 'at': DateTime.now().millisecondsSinceEpoch}});

  // ---------------------------------------------------------------- photo search

  /// Products that look like the photo, best match first. [label] is what the
  /// server's AI thinks the item is, when it has an AI key set.
  Future<({String? label, List<Product> products})> searchByPhoto(Uint8List bytes, String mime) async {
    final data = await api.request('POST', '/api/search/photo',
        body: {'image': 'data:$mime;base64,${base64Encode(bytes)}', 'limit': 30},
        timeout: const Duration(seconds: 60)) as Map<String, dynamic>;
    // Use this device's copies, so prices and stock match the rest of the app.
    final found = [for (final j in data['products'] as List) product((j as Map)['id'] as String) ?? Product.fromJson(Map<String, dynamic>.from(j))];
    return (label: data['label'] as String?, products: found);
  }

  Future<List<Order>> myOrders() async {
    final list = await api.get('/api/orders') as List;
    return list.map((e) => Order(Map<String, dynamic>.from(e as Map))).toList();
  }
}
