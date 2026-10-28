import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';
import 'orders.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Account'), automaticallyImplyLeading: false),
      body: u == null ? const _Guest() : ListView(padding: const EdgeInsets.all(16), children: [
        CardBox(
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Brand.red,
              child: Text(u.firstName.isEmpty ? '?' : u.firstName[0].toUpperCase(), style: Brand.head(24, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hi, ${u.firstName}', style: Brand.head(22)),
                const SizedBox(height: 2),
                Text(u.email, style: const TextStyle(color: Brand.muted, fontSize: 13)),
              ]),
            ),
            if (u.role == 'admin') const Pill('Admin'),
          ]),
        ),
        const SizedBox(height: 14),
        Text('How are you buying?', style: Brand.head(18)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _ModeOption(
              icon: Icons.person_outline,
              title: 'Personal',
              text: 'Retail prices, buy one or more.',
              selected: !s.isBusiness,
              onTap: () => _run(context, s.setPersonal(), 'You are buying for yourself'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeOption(
              icon: Icons.work_outline,
              title: 'Business',
              text: 'Wholesale from ${AppConfig.bulkMinQty} pieces.',
              selected: s.isBusiness,
              onTap: () => _businessSheet(context),
            ),
          ),
        ]),
        if (s.isBusiness && u.business != null) ...[
          const SizedBox(height: 10),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.storefront_outlined, color: Brand.blue),
              const SizedBox(width: 10),
              Expanded(child: Text('${u.business!['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => _businessSheet(context), child: const Text('Edit')),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        CardBox(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            _MenuRow(icon: Icons.local_shipping_outlined, title: 'Track my orders', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersScreen()))),
            const Divider(height: 1, indent: 56, color: Brand.line),
            _MenuRow(icon: Icons.favorite_border, title: 'Saved products', trailing: '${u.favs.length}', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _SavedScreen()))),
            const Divider(height: 1, indent: 56, color: Brand.line),
            _MenuRow(
              icon: Icons.support_agent,
              title: 'Customer service',
              onTap: () => showMessage(context, 'WhatsApp us on ${AppConfig.supportWhatsapp} or email ${AppConfig.supportEmail}'),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () async {
            await s.logout();
            if (context.mounted) showMessage(context, 'Signed out');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ]),
    );
  }

  static Future<void> _run(BuildContext context, Future<void> work, String ok) async {
    try {
      await work;
      if (context.mounted) showMessage(context, ok);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  static void _businessSheet(BuildContext context) {
    final s = context.read<AppState>();
    final name = TextEditingController(text: (s.user?.business?['name'] ?? '') as String);
    String? type = s.user?.business?['type'] as String?;
    final form = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: AnimationStyle(curve: easeDrawer, duration: const Duration(milliseconds: 360), reverseDuration: const Duration(milliseconds: 220)),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Buy as a business', style: Brand.head(22)),
            const SizedBox(height: 6),
            Text('Wholesale prices from ${AppConfig.bulkMinQty} pieces, your own agent and your logo on the goods. Free.',
                style: const TextStyle(color: Brand.muted, height: 1.45)),
            const SizedBox(height: 18),
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Business name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your business name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type of business'),
              items: [for (final t in AppConfig.businessTypes) DropdownMenuItem(value: t.id, child: Text(t.name))],
              onChanged: (v) => type = v,
              validator: (v) => v == null ? 'Pick your type of business' : null,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(sheetContext);
                _run(context, s.setBusiness(name.text, type!), 'You are now buying as a business');
              },
              child: const Text('Switch to business'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Guest extends StatelessWidget {
  const _Guest();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.person_outline,
      title: 'Sign in to Easy2buy',
      text: 'Save products, track your orders and unlock wholesale prices for your business.',
      action: Column(children: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(240, 50)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: const Text('Sign in'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(240, 50)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
          child: const Text('Create account'),
        ),
      ]),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final bool selected;
  final VoidCallback onTap;
  const _ModeOption({required this.icon, required this.title, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Buy as $title. $text',
        excludeSemantics: true,
        child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: easeOutStrong,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF5F6) : Colors.white,
            borderRadius: BorderRadius.circular(Brand.radiusSm),
            border: Border.all(color: selected ? Brand.red : const Color(0xFFD3D5DC), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: selected ? Brand.red600 : Brand.muted),
            const SizedBox(height: 8),
            Text(title, style: Brand.head(16)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: Brand.muted, fontSize: 12.5)),
          ]),
        ),
      ),
      );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.title, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: Brand.redSoft, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: Brand.red600, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailing != null) Text(trailing!, style: const TextStyle(color: Brand.muted)),
          const Icon(Icons.chevron_right, color: Brand.muted),
        ]),
      );
}

class _SavedScreen extends StatelessWidget {
  const _SavedScreen();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final saved = [for (final id in s.user?.favs ?? <String>[]) ?s.product(id)];
    return Scaffold(
      appBar: AppBar(title: const Text('Saved products')),
      body: saved.isEmpty
          ? const EmptyState(icon: Icons.favorite_border, title: 'Nothing saved yet', text: 'Tap the heart on any product to keep it here.')
          : ListView(padding: const EdgeInsets.all(16), children: [ProductGrid(products: saved)]),
    );
  }
}
