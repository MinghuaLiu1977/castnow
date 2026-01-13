
import { createClient } from 'redis';
import { crypto } from 'crypto';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method Not Allowed' });
  }

  const client = createClient({ url: process.env.REDIS_URL });

  try {
    await client.connect();

    // 生成一个模拟的 16 位 License Key (格式类似 Gumroad)
    const mockLicenseKey = `MOCK-${Math.random().toString(36).substring(2, 10).toUpperCase()}-${Math.random().toString(36).substring(2, 10).toUpperCase()}`;

    // 将该 Key 存入 Redis，状态为 active，有效期 24 小时
    await client.set(`license:${mockLicenseKey}`, 'active', { EX: 86400 });

    console.log(`[Mock Purchase] Generated key: ${mockLicenseKey}`);

    return res.status(200).json({ 
      success: true, 
      licenseKey: mockLicenseKey,
      message: 'Mock purchase successful. Key injected into Redis.' 
    });
  } catch (error) {
    console.error('[Mock Error]', error);
    return res.status(500).json({ success: false, message: 'Redis injection failed' });
  } finally {
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}
