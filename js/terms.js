// Eazy2buy Terms and Conditions: the one copy the website shows, both on
// terms.html and in step 2 of sign-up. The app has the same text in
// mobile/lib/terms.dart; change both together.
const TERMS = {
  updated: 'October 2026',
  effective: 'Upon account registration',
  intro: [
    `Welcome to ${APP.name} ("we," "our," or "us"). ${APP.name} is a cross-border e-commerce and wholesale sourcing platform designed to connect merchants, traders and businesses in Nigeria directly with manufacturers, factories and suppliers in China across multiple verified categories (including Electronics, Solar Tech, Fashion, Industrial Machines and more).`,
    `By registering an account, accessing our mobile application, or using our sourcing and logistics services, you agree to comply with and be bound by the following Terms and Conditions. Please read them carefully before proceeding.`
  ],
  sections: [
    {
      title: 'Acceptance of Terms',
      text: `By clicking "Agree & Continue," creating an account, or submitting an order through ${APP.name}, you acknowledge that you have read, understood and agreed to these Terms and Conditions, as well as our Privacy Policy. If you do not agree to these terms, you must not use our platform.`
    },
    {
      title: 'Eligibility & Account Registration',
      points: [
        ['User Representation', 'You must be at least 18 years old and legally capable of entering into binding commercial contracts in the Federal Republic of Nigeria.'],
        ['Account Security', 'You are responsible for maintaining the confidentiality of your login credentials (phone number, email and password) and for all activities that occur under your account.'],
        ['KYC Compliance', 'To access wholesale pricing and dedicated agent matching, you must provide accurate business profile information, including your business category and location. Providing false information may lead to account suspension.']
      ]
    },
    {
      title: 'Nature of Service & Sourcing Role',
      points: [
        ['Intermediary Platform', `${APP.name} acts as a technology platform and trade facilitator connecting Nigerian wholesale buyers with verified Chinese suppliers and managing end-to-end logistics.`],
        ['Dedicated Agent Support', 'Upon completing onboarding, users are assigned a dedicated sourcing or customer success agent to assist with inquiries, custom orders, factory negotiations and shipment tracking.'],
        ['Product Catalog', 'While we strive to maintain accurate pricing and product availability, factory prices, stock levels and raw material costs in China are subject to change based on market fluctuations and exchange rates.']
      ]
    },
    {
      title: 'Pricing, Currency & Payments',
      points: [
        ['Wholesale Pricing', 'Prices displayed on the platform are structured for wholesale and bulk purchase minimums (MOQs) set by suppliers.'],
        ['Exchange Rate & Clearances', 'Because transactions involve cross-border conversion (Naira to RMB/USD), prices may adjust based on prevailing foreign exchange rates and financial clearance frameworks.'],
        ['Payment Protection', `All payments must be routed through official ${APP.name} payment channels or escrow frameworks. Direct payments made outside the platform to third parties are done at the user's sole risk.`]
      ]
    },
    {
      title: 'Shipping, Customs Clearance & Delivery',
      points: [
        ['Cross-Border Transit', `${APP.name} partners with freight forwarders and logistics providers to ship goods from China to designated hubs in Nigeria (including clearing at ports/airports and local delivery coordination).`],
        ['Delivery Timelines', 'Estimated shipping timelines (by air or sea freight) are provided as guidelines. Delays caused by customs inspections, port congestion, airline disruptions or force majeure events are outside our direct control.'],
        ['Customs Duties', 'Standard import duties, tariffs and regulatory levies applicable in Nigeria are factored into shipping terms or billed transparently prior to final dispatch, unless stated otherwise for specific wholesale packages.']
      ]
    },
    {
      title: 'Inspection, Returns & Dispute Resolution',
      points: [
        ['Factory Quality Control', 'Our sourcing agents conduct initial checks with suppliers in China. However, buyers must inspect goods immediately upon arrival at our Nigerian pickup hubs or upon delivery.'],
        ['Defects & Discrepancies', 'Any claims regarding missing items, factory defects or wrong specifications must be reported to your dedicated agent within 48 hours of receiving the delivery, accompanied by unboxing photos/videos.'],
        ['Non-Returnable Items', 'Due to the wholesale nature of cross-border trade, customized industrial machinery, bulk apparel orders and clearance items are generally non-returnable unless proven to be structurally defective from the factory.']
      ]
    },
    {
      title: 'Prohibited Goods & Compliance',
      text: `Users are strictly prohibited from using ${APP.name} to source, import or distribute illegal items, including but not limited to:`,
      bullets: [
        'Counterfeit trademarked goods restricted by international customs laws.',
        'Unauthorized or prescription-restricted pharmaceutical products.',
        'Hazardous materials, explosives, weapons or unapproved chemical substances.',
        'Any goods violating Nigerian import laws or NAFDAC/SON regulatory guidelines.'
      ]
    },
    {
      title: 'Limitation of Liability',
      text: `${APP.name}, its founders, employees and logistics partners shall not be held liable for indirect, incidental or consequential damages (including loss of business profits, trade delays caused by customs authorities, or third-party manufacturer defaults) exceeding the total service fees or product deposits paid by the user for the specific disputed transaction.`
    },
    {
      title: 'Modifications to Terms',
      text: 'We reserve the right to update or modify these Terms and Conditions at any time to reflect changes in our business operations, legal requirements or tech features. Continued use of the app after modifications constitutes your acceptance of the updated terms.'
    },
    {
      title: 'Governing Law',
      text: 'These Terms and Conditions shall be governed by and construed in accordance with the laws of the Federal Republic of Nigeria. Any disputes arising out of these terms shall be subject to the exclusive jurisdiction of the courts in Nigeria.'
    }
  ]
};

// The terms as HTML, numbered 1 to 10.
function termsHtml() {
  return `
    <p class="small muted"><b>Last updated:</b> ${esc(TERMS.updated)} · <b>Effective:</b> ${esc(TERMS.effective)}</p>
    ${TERMS.intro.map((p) => `<p class="mt-12">${esc(p)}</p>`).join('')}
    ${TERMS.sections.map((s, i) => `
      <section class="terms-section">
        <h2>${i + 1}. ${esc(s.title)}</h2>
        ${s.text ? `<p>${esc(s.text)}</p>` : ''}
        ${s.points ? `<ul>${s.points.map(([t, d]) => `<li><b>${esc(t)}:</b> ${esc(d)}</li>`).join('')}</ul>` : ''}
        ${s.bullets ? `<ul>${s.bullets.map((b) => `<li>${esc(b)}</li>`).join('')}</ul>` : ''}
      </section>`).join('')}`;
}
