// Brand settings. Change the name here and every page picks it up.
const APP = {
  name: 'Easy2buy',
  tagline: 'Shop China. Pay in Naira.',
  supportEmail: 'support@example.com',
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

// Optional: the web address of your own AI service. While it is empty, the business
// assistant answers from the product catalogue and built-in tips. When set, the assistant
// POSTs { messages, user } to it and shows the "reply" text it returns. Keep any AI API key
// on that server, never in this file.
const ASSISTANT_ENDPOINT = '';
