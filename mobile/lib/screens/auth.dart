import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Pops with `true` once signed in, so the screen that sent you here can carry on.
class LoginScreen extends StatefulWidget {
  final String? reason;
  const LoginScreen({super.key, this.reason});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AppState>().login(_email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: widget.reason ?? 'Sign in to your Easy2buy account.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: (v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email address',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
            ),
            validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const _Spinner() : const Text('Sign in')),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('New to Easy2buy? ', style: TextStyle(color: Brand.muted)),
            GestureDetector(
              onTap: () async {
                final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SignupScreen()));
                if (ok == true && context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Create an account', style: TextStyle(color: Brand.red600, fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  // A shared invite link looks like https://app.../?ref=CODE; pre-fill it.
  final _referral = TextEditingController(text: Uri.base.queryParameters['ref']?.toUpperCase() ?? '');
  bool _busy = false, _hide = true, _terms = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _referral]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      setState(() => _error = 'Please agree to the terms to continue.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final s = context.read<AppState>();
      await s.signup(name: _name.text.trim(), phone: _phone.text.trim(), email: _email.text.trim(), password: _password.text, referralCode: _referral.text);
      await s.updateAccount({'termsAcceptedAt': DateTime.now().millisecondsSinceEpoch}).catchError((_) {});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'Shop for yourself, or switch to Business later for wholesale prices.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your full name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) => RegExp(r'^[0-9+\s-]{7,}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid phone number',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: (v) => RegExp(r'^\S+@\S+\.\S+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email address',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _hide,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
            ),
            validator: (v) => (v ?? '').length < 6 ? 'Your password needs at least 6 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _referral,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Referral code (optional)',
              helperText: 'Got one from a friend? You get money off your first order.',
              prefixIcon: Icon(Icons.card_giftcard_outlined),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _terms,
            onChanged: (v) => setState(() => _terms = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Brand.red,
            title: const Text('I agree to the Terms of Service and the Escrow & Buyer Protection Policy.', style: TextStyle(fontSize: 13)),
          ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const _Spinner() : const Text('Create account')),
        ]),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _AuthScaffold({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
              const Align(alignment: Alignment.centerLeft, child: LogoMark(size: 48)),
              const SizedBox(height: 22),
              Text(title, style: Brand.head(30, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Brand.muted, height: 1.45)),
              const SizedBox(height: 26),
              child,
            ]),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, color: Brand.red600, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Brand.red600, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white));
}
