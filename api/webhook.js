
import { createClient } from 'redis';

export default async function handler(req, res) {
  // 1. Method Restriction
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).send('Method Not Allowed');
  }

  const client = createClient({ url: process.env.REDIS_URL });

  try {
    // 2. Body Parsing Check
    // Vercel pre-parses form-urlencoded. Ensure it exists.
    const body = req.body;
    if (!body || typeof body !== 'object') {
      return res.status(400).send('Invalid Payload');
    }

    // 3. Security Check: Permalink Verification
    // Critical: Only process requests for the specific product 'ihhtg'
    if (body.permalink !== 'ihhtg') {
      console.warn(`[Security] Unauthorized webhook attempt for permalink: ${body.permalink}`);
      return res.status(403).send('Forbidden: Product ID Mismatch');
    }

    const licenseKey = body.license_key;

    if (licenseKey) {
      // 4. Redis Operations
      await client.connect();
      
      // Store status 'active' with a strict 24-hour TTL (86400 seconds)
      await client.set(`license:${licenseKey}`, 'active', { EX: 86400 });
      
      console.log(`[Success] License activated: ${licenseKey.substring(0, 8)}...`);
    }

    // 5. Success Response
    return res.status(200).send('Webhook Processed');
  } catch (error) {
    console.error('[Error] Webhook processing failed:', error.message);
    return res.status(500).send('Internal Server Error');
  } finally {
    // 6. Cleanup: Prevent connection leaks and lambda timeouts
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}
