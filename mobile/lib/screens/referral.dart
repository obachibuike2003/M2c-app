import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../app_state.dart';
import '../config.dart';
import '../media.dart';
import '../theme.dart';
import '../widgets.dart';

/// Invite friends: your code, a share link, what you've earned, and a box to
/// add a friend's code if you signed up without one.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<Map<String, dynamic>> _info;
  final _code = TextEditingController();
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _info = context.read<AppState>().referral();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _link(String code) => '${AppConfig.appUrl}/?ref=$code';

  String _message(String code, int reward) =>
      'Shop factory prices from China, paid in naira, on ${AppConfig.appName}. Sign up with my code $code '
      'and get ${money(reward)} off your first order: ${_link(code)}';

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await context.read<AppState>().applyReferral(_code.text);
      if (!mounted) return;
      showMessage(context, 'Code added. Your credit comes off your first order.');
      setState(() => _info = context.read<AppState>().referral());
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _info,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Brand.red));
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn\'t load your code',
              text: '${snap.error}',
              action: FilledButton(onPressed: () => setState(() => _info = context.read<AppState>().referral()), child: const Text('Try again')),
            );
          }
          final d = snap.data!;
          final code = '${d['code']}';
          final reward = (d['reward'] as num).toInt();
          final credit = (d['credit'] as num).toInt();

          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF111216), Color(0xFF2A2C33)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('INVITE & EARN', style: TextStyle(color: Color(0xFFFFC83D), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
                const SizedBox(height: 8),
                Text('Give ${money(reward)}, get ${money(reward)}', style: Brand.head(28, weight: FontWeight.w800, color: Colors.white).copyWith(height: 1.1)),
                const SizedBox(height: 8),
                Text('Friends who sign up with your code get ${money(reward)} off their first order. When they place it, you get ${money(reward)} off your next one.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.45)),
                const SizedBox(height: 18),
                // The code, tap to copy.
                Semantics(
                  button: true,
                  label: 'Your code $code. Copy',
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) showMessage(context, 'Code copied');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFC83D), width: 1.5),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(code, style: Brand.head(28, weight: FontWeight.w800, color: Colors.white).copyWith(letterSpacing: 3))),
                        const Icon(Icons.copy_rounded, color: Color(0xFFFFC83D)),
                        const SizedBox(width: 6),
                        const Text('Copy', style: TextStyle(color: Color(0xFFFFC83D), fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FA855)),
                      onPressed: () => openLink(context, Uri.https('wa.me', '/', {'text': _message(code, reward)})),
                      icon: const Icon(Icons.chat_outlined, size: 19),
                      label: const Text('Share on WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Copy invite link',
                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12), minimumSize: const Size(52, 52)),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _message(code, reward)));
                      if (context.mounted) showMessage(context, 'Invite link copied. Paste it anywhere.');
                    },
                    icon: const Icon(Icons.link_rounded, color: Colors.white),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _stat('${d['invited']}', 'Friends joined'),
              const SizedBox(width: 10),
              _stat('${d['ordered']}', 'Have ordered'),
              const SizedBox(width: 10),
              _stat(money((d['earned'] as num).toInt()), 'Earned'),
            ]),
            const SizedBox(height: 14),
            CardBox(
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Brand.greenSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.savings_outlined, color: Brand.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(credit > 0 ? '${money(credit)} ready to use' : 'No credit yet', style: Brand.head(17)),
                    Text(credit > 0 ? 'It comes off your next order automatically.' : 'Share your code to start earning.',
                        style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            if (d['canApply'] == true) ...[
              const SizedBox(height: 14),
              CardBox(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Got a code from a friend?', style: Brand.head(17)),
                  const SizedBox(height: 4),
                  Text('Add it before your first order and get ${money(reward)} off.', style: const TextStyle(color: Brand.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: 'e.g. ADA1F3', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _applying ? null : _apply, child: const Text('Add')),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            CardBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('How it works', style: Brand.head(17)),
                const SizedBox(height: 8),
                for (final (i, t) in [
                  'Share your code or link with friends.',
                  'They sign up with it and get ${money(reward)} off their first order.',
                  'When they place that order, you get ${money(reward)} off your next one.',
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 11, backgroundColor: Brand.redSoft, child: Text('${i + 1}', style: const TextStyle(color: Brand.red600, fontSize: 12, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
                    ]),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: CardBox(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Text(value, style: Brand.head(20), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Brand.muted, fontSize: 12), textAlign: TextAlign.center),
          ]),
        ),
      );
}
