
import { createClient } from 'redis';

export default async function handler(req, res) {
  // 1. CORS Configuration
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  // 2. Preflight Response
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

  const client = createClient({ url: process.env.REDIS_URL });

  try {
    await client.connect();
    
    // 3. Status Retrieval
    const status = await client.get(`license:${licenseKey}`);
    
    if (status === 'active') {
      return res.status(200).json({ valid: true });
    } else {
      // Key not found or expired
      return res.status(200).json({ valid: false });
    }
  } catch (error) {
    console.error('[Error] Redis Verification Failure:', error.message);
    return res.status(500).json({ 
      valid: false, 
      message: 'Service Temporarily Unavailable' 
    });
  } finally {
    // 4. Cleanup
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}
