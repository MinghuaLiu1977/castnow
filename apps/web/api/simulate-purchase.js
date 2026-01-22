
export default async function handler(req, res) {
  return res.status(403).json({ message: 'Simulation disabled in production.' });
}
