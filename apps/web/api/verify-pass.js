import { createClient } from 'redis';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ valid: false, message: 'Method Not Allowed' });
  }

  const { licenseKey } = req.body;

  if (!licenseKey) {
    return res.status(400).json({ valid: false, message: 'License key is required' });
  }

  // Check if Redis URL is configured
  if (!process.env.REDIS_URL) {
    console.error('[System] REDIS_URL not set.');
    return res.status(500).json({ valid: false, message: 'Server Configuration Error' });
  }

  const client = createClient({ url: process.env.REDIS_URL });

  client.on('error', (err) => console.error('Redis Client Error', err));

  try {
    await client.connect();

    // 从 Redis 获取状态
    // Key 格式必须与 webhook.js 中存储的一致: `license:${licenseKey}`
    const status = await client.get(`license:${licenseKey}`);

    if (status === 'active') {
      // 获取剩余秒数 (TTL)
      const ttl = await client.ttl(`license:${licenseKey}`);
      return res.status(200).json({
        valid: true,
        expiresIn: ttl > 0 ? ttl : 0 // 确保不返回负数
      });
    } else {
      // Redis 中不存在或已过期
      return res.status(200).json({ valid: false, message: 'License key not found or expired' });
    }
  } catch (error) {
    console.error('[Error] Redis Operation Failed:', error.message);
    // Continue to fallback if Redis fails, or just return error?
    // If Redis is down, we might want to still verify via Gumroad but we can't cache it.
    // Let's proceed to fallback but without caching if client is not connected.
  }

  // 2. Fallback: Gumroad API Verification
  // If we found it in Redis in the try block, we returned already.
  // If we are here, it means it's not in Redis (or Redis failed).

  console.log(`[Verify] Cache miss for ${licenseKey.substring(0, 8)}... Verifying with Gumroad.`);

  try {
    const gumroadResponse = await fetch('https://api.gumroad.com/v2/licenses/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        product_permalink: 'ihhtg', // Product ID from webhook.js
        license_key: licenseKey
      })
    });

    if (!gumroadResponse.ok) {
      console.warn('[Verify] Gumroad API error:', gumroadResponse.status);
      return res.status(200).json({ valid: false, message: 'Invalid license key' });
    }

    const data = await gumroadResponse.json();

    if (data.success && !data.purchase.refunded && !data.purchase.chargebacked) {
      // Security: Verify Seller ID
      // This ensures the license key belongs to YOUR product, not just any valid Gumroad product.
      if (data.purchase.seller_id !== process.env.GUMROAD_SELLER_ID) {
        console.warn(`[Security] Seller ID mismatch in API verification. Got: ${data.purchase.seller_id}`);
        return res.status(200).json({ valid: false, message: 'Invalid license (Seller mismatch)' });
      }

      // Purchase exists. Now check if it's within 7 days.
      const purchaseDate = new Date(data.purchase.created_at);
      const now = new Date();
      const diffMs = now - purchaseDate;
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

      if (diffMs < sevenDaysMs) {
        // Valid and active!
        const remainingMs = sevenDaysMs - diffMs;
        const remainingSeconds = Math.ceil(remainingMs / 1000);

        // Cache in Redis for the remaining time
        if (client.isOpen) {
          try {
            await client.set(`license:${licenseKey}`, 'active', { EX: remainingSeconds });
            console.log(`[Verify] Cached ${licenseKey.substring(0, 8)}... with TTL ${remainingSeconds}s`);
          } catch (cacheErr) {
            console.error('[Verify] Failed to cache to Redis:', cacheErr);
          }
        }

        return res.status(200).json({
          valid: true,
          expiresIn: remainingSeconds
        });
      } else {
        return res.status(200).json({ valid: false, message: 'Pass expired (7-day limit)' });
      }
    } else {
      return res.status(200).json({ valid: false, message: 'Invalid or refunded license' });
    }
  } catch (apiError) {
    console.error('[Error] Gumroad API Verification Failed:', apiError);
    return res.status(500).json({ valid: false, message: 'Verification Service Unavailable' });
  } finally {
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}