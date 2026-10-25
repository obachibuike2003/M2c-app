// Brand settings. Change the name here and every page picks it up.
const APP = {
  name: 'Easy2buy',
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
const API_BASE = 'https://m2c.13-48-31-7.sslip.io';

// Optional: the web address of your own AI service. While it is empty, the business
// assistant answers from the product catalogue and built-in tips. When set, the assistant
// POSTs { messages, user } to it and shows the "reply" text it returns. Keep any AI API key
// on that server, never in this file.
const ASSISTANT_ENDPOINT = '';

// Optional: the web address of the backend's image-generation route (see
// backend/app.py, POST /api/design/generate). While it is empty, AiStudio's
// "Generate" button just explains that AI generation isn't connected yet.
// When set, it POSTs { prompt } and expects either { image: "data:..." } or
// { error: "..." } back. Run the Flask backend locally and point this at it,
// e.g. 'http://127.0.0.1:5000/api/design/generate'.
const AI_DESIGN_ENDPOINT = '';
