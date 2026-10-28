import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../config.dart';
import '../media.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account.dart';
import 'assistant.dart';
import 'orders.dart';

/// Customer service, the website's support.html.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    final agent = s.isBusiness ? AppConfig.agents.where((a) => a.id == u?.raw['agentId']).firstOrNull : null;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: const Text('Customer service')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const Text('Questions about an order, your wallet or your account? Here\'s every way to reach us.', style: TextStyle(color: Brand.muted, height: 1.45)),
        const SizedBox(height: 14),
        // Customer care chat: answers straight away, and hands anything serious to a person.
        Semantics(
          button: true,
          label: 'Chat with customer care',
          excludeSemantics: true,
          child: Pressable(
          onTap: () => u == null
              ? showMessage(context, 'Sign in to chat with customer care, or WhatsApp us below.')
              : push(const AssistantScreen(support: true)),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Brand.radius),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF3A50), Brand.red, Brand.red700]),
              boxShadow: const [BoxShadow(color: Color(0x33E0182D), blurRadius: 22, offset: Offset(0, 10))],
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.support_agent, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Chat with customer care', style: Brand.head(17, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Answers in seconds. A person takes over when you need one.', style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ]),
          ),
        ),
        ),
        if (agent != null) ...[
          const SizedBox(height: 14),
          CardBox(
            child: Row(children: [
              CircleAvatar(radius: 24, backgroundColor: Brand.red, child: Text(agent.name[0], style: Brand.head(20, color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR AGENT', style: TextStyle(color: Brand.red600, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  Text(agent.name, style: Brand.head(18)),
                  const Text('Fastest for bulk orders, custom branding and delivery questions.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                ]),
              ),
              IconButton.filled(
                tooltip: 'WhatsApp ${agent.name}',
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF1FA855)),
                onPressed: () => openLink(context, whatsappLink(agent.whatsapp, 'Hi ${agent.name}, this is ${u!.name} on ${AppConfig.appName}.')),
                icon: const Icon(Icons.chat_outlined, color: Colors.white),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        TwoColumn(children: [
          ToolCard(icon: Icons.chat_outlined, title: 'WhatsApp us', text: AppConfig.supportWhatsapp,
              onTap: () => openLink(context, whatsappLink(supportWhatsappDigits, 'Hi ${AppConfig.appName}, I need some help.'))),
          ToolCard(icon: Icons.mail_outline, title: 'Email us', text: 'For anything that can wait a day.', onTap: () => openLink(context, emailLink(AppConfig.supportEmail))),
          ToolCard(icon: Icons.smart_toy_outlined, title: 'Ask the AI assistant', text: 'Products, prices and tips.',
              onTap: () => s.isBusiness ? push(const AssistantScreen()) : showMessage(context, 'The assistant is for business buyers. Switch to Business first.')),
          ToolCard(icon: Icons.local_shipping_outlined, title: 'Track my goods', text: 'Every step to your door.', onTap: () => push(const OrdersScreen())),
        ]),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Common questions', style: Brand.head(19)),
            const SizedBox(height: 6),
            for (final (q, a) in [
              ('Where is my order?', 'Open My orders and tap any order to see its live tracking stage.'),
              ('How do I get a refund?', 'If an order doesn\'t arrive or doesn\'t match what was ordered, the amount paid is returned to your ${AppConfig.appName} wallet. WhatsApp us with your order number.'),
              ('How do I switch to business buying?', 'Tap Business at the top of Home, or choose Business on your Account page, to unlock wholesale prices, an agent and logo branding.'),
              ('How do I verify my identity?', 'Go to Account upgrades & KYC and take a quick selfie. Verified buyers get faster approval on big orders.'),
            ])
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedAlignment: Alignment.centerLeft,
                children: [Text(a, style: const TextStyle(color: Brand.muted, height: 1.45))],
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Account upgrades & KYC, the website's kyc.html: a selfie for the team to check.
class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  static const _text = {
    'none': 'Take a quick selfie so we know it is really you.',
    'pending': 'Thanks! Your selfie is waiting for our team to check it.',
    'verified': 'Your identity is verified.',
    'rejected': 'We could not verify that photo. Please take a clear selfie in good light.',
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    if (u == null) return const AccountScreen();
    final v = u.verifyStatus;
    final (label, bg, fg) = switch (v) {
      'verified' => ('Verified', Brand.greenSoft, Brand.green),
      'pending' => ('Pending', const Color(0xFFFFF1D6), const Color(0xFF8F4D00)),
      'rejected' => ('Rejected', Brand.redSoft, Brand.red600),
      _ => ('Not verified', const Color(0xFFECECF0), Brand.muted),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Account upgrades & KYC')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const Text('Verifying your identity unlocks faster approval on big orders.', style: TextStyle(color: Brand.muted, height: 1.45)),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text('Identity check', style: Brand.head(19))), Pill(label, bg: bg, fg: fg)]),
            const SizedBox(height: 8),
            Text(_text[v] ?? _text['none']!, style: const TextStyle(color: Brand.muted, height: 1.45)),
            if (v == 'none' || v == 'rejected') ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final photo = await pickImageDataUrl(context, source: ImageSource.camera, camera: CameraDevice.front, maxSize: 360);
                  if (photo == null || !context.mounted) return;
                  try {
                    await s.submitVerification(photo);
                    if (context.mounted) showMessage(context, 'Selfie sent for checking');
                  } catch (e) {
                    if (context.mounted) showMessage(context, e.toString(), error: true);
                  }
                },
                icon: const Icon(Icons.photo_camera_outlined, size: 19),
                label: const Text('Take a selfie'),
              ),
              const SizedBox(height: 6),
              const Text('This opens your front camera. Our team checks the photo, then removes it.', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('What verifying unlocks', style: Brand.head(19)),
            const SizedBox(height: 12),
            for (final (icon, title, text) in const [
              (Icons.bolt_rounded, 'Faster approval', 'Quicker checks on large or bulk orders'),
              (Icons.verified_user_outlined, 'Trust signal', 'Shows you\'re a verified buyer to our team'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Brand.redSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: Brand.red600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(text, style: const TextStyle(color: Brand.muted, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
