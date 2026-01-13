
import { createClient } from 'redis';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method Not Allowed' });
  }

  // 检查 Redis URL 是否配置
  if (!process.env.REDIS_URL) {
    return res.status(200).json({ 
      success: true, 
      licenseKey: `LOCAL-DEV-${Math.random().toString(36).substring(2, 10).toUpperCase()}`,
      message: 'Redis not configured. Generated a local-only key for development.' 
    });
  }

  const client = createClient({ url: process.env.REDIS_URL });

  try {
    await client.connect();

    // 生成一个模拟的 16 位 License Key
    const mockLicenseKey = `MOCK-${Math.random().toString(36).substring(2, 10).toUpperCase()}-${Math.random().toString(36).substring(2, 10).toUpperCase()}`;

    // 存入 Redis，有效期 24 小时
    await client.set(`license:${mockLicenseKey}`, 'active', { EX: 86400 });

    return res.status(200).json({ 
      success: true, 
      licenseKey: mockLicenseKey,
      message: 'Mock purchase successful. Key injected into Redis.' 
    });
  } catch (error) {
    console.error('[Mock Error]', error);
    // 即便 Redis 连接失败，也返回一个 Key 给前端展示，避免流程卡死
    return res.status(200).json({ 
      success: true, 
      licenseKey: `OFFLINE-${Math.random().toString(36).substring(2, 10).toUpperCase()}`,
      message: 'Database connection failed, using offline fallback.' 
    });
  } finally {
    if (client.isOpen) {
      await client.disconnect();
    }
  }
}
