import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';

/// Eazy2buy Terms and Conditions: the same text as the website's js/terms.js.
/// Change both together.
const _name = AppConfig.appName;

const termsUpdated = 'October 2026';
const termsEffective = 'Upon account registration';

const termsIntro = [
  'Welcome to $_name ("we," "our," or "us"). $_name is a cross-border e-commerce and wholesale sourcing platform designed to connect merchants, traders and businesses in Nigeria directly with manufacturers, factories and suppliers in China across multiple verified categories (including Electronics, Solar Tech, Fashion, Industrial Machines and more).',
  'By registering an account, accessing our mobile application, or using our sourcing and logistics services, you agree to comply with and be bound by the following Terms and Conditions. Please read them carefully before proceeding.',
];

typedef TermsSection = ({String title, String? text, List<(String, String)> points, List<String> bullets});

const List<TermsSection> termsSections = [
  (
    title: 'Acceptance of Terms',
    text: 'By clicking "Agree & Continue," creating an account, or submitting an order through $_name, you acknowledge that you have read, understood and agreed to these Terms and Conditions, as well as our Privacy Policy. If you do not agree to these terms, you must not use our platform.',
    points: [],
    bullets: [],
  ),
  (
    title: 'Eligibility & Account Registration',
    text: null,
    points: [
      ('User Representation', 'You must be at least 18 years old and legally capable of entering into binding commercial contracts in the Federal Republic of Nigeria.'),
      ('Account Security', 'You are responsible for maintaining the confidentiality of your login credentials (phone number, email and password) and for all activities that occur under your account.'),
      ('KYC Compliance', 'To access wholesale pricing and dedicated agent matching, you must provide accurate business profile information, including your business category and location. Providing false information may lead to account suspension.'),
    ],
    bullets: [],
  ),
  (
    title: 'Nature of Service & Sourcing Role',
    text: null,
    points: [
      ('Intermediary Platform', '$_name acts as a technology platform and trade facilitator connecting Nigerian wholesale buyers with verified Chinese suppliers and managing end-to-end logistics.'),
      ('Dedicated Agent Support', 'Upon completing onboarding, users are assigned a dedicated sourcing or customer success agent to assist with inquiries, custom orders, factory negotiations and shipment tracking.'),
      ('Product Catalog', 'While we strive to maintain accurate pricing and product availability, factory prices, stock levels and raw material costs in China are subject to change based on market fluctuations and exchange rates.'),
    ],
    bullets: [],
  ),
  (
    title: 'Pricing, Currency & Payments',
    text: null,
    points: [
      ('Wholesale Pricing', 'Prices displayed on the platform are structured for wholesale and bulk purchase minimums (MOQs) set by suppliers.'),
      ('Exchange Rate & Clearances', 'Because transactions involve cross-border conversion (Naira to RMB/USD), prices may adjust based on prevailing foreign exchange rates and financial clearance frameworks.'),
      ('Payment Protection', 'All payments must be routed through official $_name payment channels or escrow frameworks. Direct payments made outside the platform to third parties are done at the user\'s sole risk.'),
    ],
    bullets: [],
  ),
  (
    title: 'Shipping, Customs Clearance & Delivery',
    text: null,
    points: [
      ('Cross-Border Transit', '$_name partners with freight forwarders and logistics providers to ship goods from China to designated hubs in Nigeria (including clearing at ports/airports and local delivery coordination).'),
      ('Delivery Timelines', 'Estimated shipping timelines (by air or sea freight) are provided as guidelines. Delays caused by customs inspections, port congestion, airline disruptions or force majeure events are outside our direct control.'),
      ('Customs Duties', 'Standard import duties, tariffs and regulatory levies applicable in Nigeria are factored into shipping terms or billed transparently prior to final dispatch, unless stated otherwise for specific wholesale packages.'),
    ],
    bullets: [],
  ),
  (
    title: 'Inspection, Returns & Dispute Resolution',
    text: null,
    points: [
      ('Factory Quality Control', 'Our sourcing agents conduct initial checks with suppliers in China. However, buyers must inspect goods immediately upon arrival at our Nigerian pickup hubs or upon delivery.'),
      ('Defects & Discrepancies', 'Any claims regarding missing items, factory defects or wrong specifications must be reported to your dedicated agent within 48 hours of receiving the delivery, accompanied by unboxing photos/videos.'),
      ('Non-Returnable Items', 'Due to the wholesale nature of cross-border trade, customized industrial machinery, bulk apparel orders and clearance items are generally non-returnable unless proven to be structurally defective from the factory.'),
    ],
    bullets: [],
  ),
  (
    title: 'Prohibited Goods & Compliance',
    text: 'Users are strictly prohibited from using $_name to source, import or distribute illegal items, including but not limited to:',
    points: [],
    bullets: [
      'Counterfeit trademarked goods restricted by international customs laws.',
      'Unauthorized or prescription-restricted pharmaceutical products.',
      'Hazardous materials, explosives, weapons or unapproved chemical substances.',
      'Any goods violating Nigerian import laws or NAFDAC/SON regulatory guidelines.',
    ],
  ),
  (
    title: 'Limitation of Liability',
    text: '$_name, its founders, employees and logistics partners shall not be held liable for indirect, incidental or consequential damages (including loss of business profits, trade delays caused by customs authorities, or third-party manufacturer defaults) exceeding the total service fees or product deposits paid by the user for the specific disputed transaction.',
    points: [],
    bullets: [],
  ),
  (
    title: 'Modifications to Terms',
    text: 'We reserve the right to update or modify these Terms and Conditions at any time to reflect changes in our business operations, legal requirements or tech features. Continued use of the app after modifications constitutes your acceptance of the updated terms.',
    points: [],
    bullets: [],
  ),
  (
    title: 'Governing Law',
    text: 'These Terms and Conditions shall be governed by and construed in accordance with the laws of the Federal Republic of Nigeria. Any disputes arising out of these terms shall be subject to the exclusive jurisdiction of the courts in Nigeria.',
    points: [],
    bullets: [],
  ),
];

/// The terms as a readable page, numbered 1 to 10.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(height: 1.55, color: Brand.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Terms and Conditions')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        const Text('LEGAL', style: TextStyle(color: Brand.red600, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text('$_name Terms and Conditions', style: Brand.head(26).copyWith(height: 1.15)),
        const SizedBox(height: 8),
        const Text('Last updated: $termsUpdated · Effective: $termsEffective', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
        for (final p in termsIntro) Padding(padding: const EdgeInsets.only(top: 12), child: Text(p, style: body)),
        for (final (i, s) in termsSections.indexed) ...[
          const SizedBox(height: 22),
          Text('${i + 1}. ${s.title}', style: Brand.head(18)),
          const SizedBox(height: 8),
          if (s.text != null) Text(s.text!, style: body),
          for (final (t, d) in s.points)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _Bullet(Text.rich(TextSpan(children: [TextSpan(text: '$t: ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: d)]), style: body)),
            ),
          for (final b in s.bullets) Padding(padding: const EdgeInsets.only(top: 8), child: _Bullet(Text(b, style: body))),
        ],
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  final Widget child;
  const _Bullet(this.child);

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 8, right: 10), child: CircleAvatar(radius: 3, backgroundColor: Brand.red)),
        Expanded(child: child),
      ]);
}
