// Brand settings. Change the name here and every page picks it up.
const APP = {
  name: 'Eazy2buy',
  tagline: 'Shop China. Pay in Naira.',
  supportEmail: 'support@example.com',
  supportWhatsapp: '2348000000000',
  shippingFee: 2500,
  freeShippingFrom: 50000
};

// Starting rules for business (bulk) buying. The admin panel can change them later.
// tiers: buy at least "from" pieces of one item and get "off" percent off that item.
const SEED_BULK = {
  minQty: 10,
  tiers: [
    { from: 10, off: 5 },
    { from: 50, off: 10 },
    { from: 100, off: 15 }
  ]
};

// The backend (backend/app.py). Accounts and the product catalogue live there;
// each page loads them from it before rendering.
const API_BASE = 'https://api.eazy2buychina.com';

// AI features run on the backend, which keeps the OpenAI key: the business
// assistant and customer care (POST /api/assistant/chat) and AiStudio's
// "Generate" (POST /api/design/generate). They need a signed-in account; if
// the backend has no key, the assistant falls back to its built-in answers.
const AI_DESIGN_ENDPOINT = '/api/design/generate';
