
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

  const client = createClient({ url: process.env.REDIS_URL });

  try {
    await client.connect();
    
    // 获取状态
    const status = await client.get(`license:${licenseKey}`);
    
    if (status === 'active') {
      // 获取剩余秒数 (TTL)
      const ttl = await client.ttl(`license:${licenseKey}`);
      return res.status(200).json({ 
        valid: true, 
        expiresIn: ttl // 返回剩余秒数
      });
    } else {
      return res.status(200).json({ valid: false });
    }
  } catch (error) {
    console.error('[Error] Redis Verification Failure:', error.message);
    return res.status(500).json({ 
      valid: false, 
      message: 'Service Temporarily Unavailable' 
    });
  } finally {
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}
