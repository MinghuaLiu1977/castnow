import { createClient } from 'redis';

export default async function handler(req, res) {
  // 1. Method Restriction
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).send('Method Not Allowed');
  }

  // 2. Environment Check
  if (!process.env.REDIS_URL || !process.env.GUMROAD_WEBHOOK_SECRET || !process.env.GUMROAD_SELLER_ID) {
    console.error('[System] Missing environment variables (REDIS_URL, GUMROAD_WEBHOOK_SECRET, or GUMROAD_SELLER_ID).');
    return res.status(500).send('Server Configuration Error');
  }

  // 3. Security: URL Query Secret Check
  // Gumroad doesn't sign requests, so we use a secret in the URL (e.g. ?secret=XYZ)
  const { secret } = req.query;
  if (secret !== process.env.GUMROAD_WEBHOOK_SECRET) {
    console.warn('[Security] Unauthorized webhook attempt (invalid secret).');
    return res.status(403).send('Forbidden');
  }

  const client = createClient({ url: process.env.REDIS_URL });

  // Error handling for the Redis client itself
  client.on('error', (err) => console.error('[Redis Client Error]', err));

  try {
    // 4. Body Parsing Check
    const body = req.body;
    if (!body || typeof body !== 'object') {
      console.warn('[Webhook] Invalid Payload received');
      return res.status(400).send('Invalid Payload');
    }

    // Log the event (masking sensitive data)
    console.log(`[Webhook] Received for product: ${body.permalink}, sale_id: ${body.sale_id}`);

    // 5. Security Check: Permalink & Seller ID Verification
    // Ensure this webhook is for the correct product and from the correct seller.
    if (body.permalink !== 'ihhtg') {
      console.warn(`[Security] Unauthorized webhook attempt for permalink: ${body.permalink}`);
      return res.status(200).send('Ignored: Product ID Mismatch');
    }

    if (body.seller_id !== process.env.GUMROAD_SELLER_ID) {
      console.warn(`[Security] Seller ID mismatch: ${body.seller_id}`);
      return res.status(403).send('Forbidden: Seller ID Mismatch');
    }

    // Gumroad sends 'license_key'
    const licenseKey = body.license_key;

    if (licenseKey) {
      // 5. Redis Operations
      await client.connect();

      // Store status 'active' with a 7-day TTL (604800 seconds)
      // We use the key format `license:{LICENSE_KEY}`
      await client.set(`license:${licenseKey}`, 'active', { EX: 604800 });


      console.log(`[Success] License activated in Redis: ${licenseKey.substring(0, 8)}...`);
    } else {
      console.warn('[Webhook] No license_key found in payload');
    }

    // 6. Success Response
    return res.status(200).send('Webhook Processed Successfully');
  } catch (error) {
    console.error('[Error] Webhook processing failed:', error);
    // Return 500 so Gumroad might retry later (though usually we want to fix code)
    return res.status(500).send('Internal Server Error');
  } finally {
    // 7. Cleanup
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}