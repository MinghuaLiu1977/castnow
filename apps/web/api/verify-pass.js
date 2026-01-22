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
    console.error('[Error] Redis Verification Failure:', error.message);
    return res.status(500).json({ 
      valid: false, 
      message: 'Verification Service Unavailable' 
    });
  } finally {
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}