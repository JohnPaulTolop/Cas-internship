import { createStaffEvaluation, getPublicEvaluation, submitPublicEvaluation, verifyPublicEvaluationAccess } from '../tools/evaluation_core.mjs';

export default async function handler(req, res) {
  const allowedOrigin = process.env.APP_ORIGIN?.trim();
  if (allowedOrigin) res.setHeader('Access-Control-Allow-Origin', allowedOrigin);
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Vary', 'Origin');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  try {
    const result = req.method === 'GET'
      ? await getPublicEvaluation({ token: req.query?.token })
      : req.method === 'POST'
        ? (req.body?.action === 'create'
? await createStaffEvaluation({
    authorization: req.headers.authorization,
    body: req.body,
  })
: req.body?.action === 'verify'
            ? await verifyPublicEvaluationAccess({ body: req.body })
            : await submitPublicEvaluation({ body: req.body }))
        : { status: 405, payload: { error: 'Method not allowed.' } };
    res.status(result.status).json(result.payload);
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
