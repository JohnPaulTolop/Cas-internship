import { ensureStaffClaims } from '../tools/staff_claims_core.mjs';

export default async function handler(req, res) {
  const allowedOrigin = process.env.APP_ORIGIN?.trim();
  if (allowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', allowedOrigin);
  }
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Vary', 'Origin');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed.' });
    return;
  }

  try {
    const result = await ensureStaffClaims({
      authorization: req.headers.authorization,
    });
    res.status(result.status).json(result.payload);
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
