import http from 'node:http';
import { reviewCoordinatorRequest } from './coordinator_approval_core.mjs';
import { ensureStaffClaims } from './staff_claims_core.mjs';
import { getPublicEvaluation, submitPublicEvaluation, verifyPublicEvaluationAccess } from './evaluation_core.mjs';

const host = process.env.APPROVAL_HOST || '127.0.0.1';
const port = Number(process.env.APPROVAL_PORT || 8787);

function send(res, status, payload) {
  res.writeHead(status);
  res.end(JSON.stringify(payload));
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const requestUrl = new URL(req.url || '/', `http://${req.headers.host || `${host}:${port}`}`);

  try {
    if (req.method === 'POST' && requestUrl.pathname === '/api/coordinator-approval') {
      let raw = '';
      for await (const chunk of req) raw += chunk;
      const result = await reviewCoordinatorRequest({
        authorization: req.headers.authorization,
        body: raw,
      });
      send(res, result.status, result.payload);
      return;
    }

    if (req.method === 'POST' && requestUrl.pathname === '/api/staff-claims') {
      const result = await ensureStaffClaims({
        authorization: req.headers.authorization,
      });
      send(res, result.status, result.payload);
      return;
    }

    if (requestUrl.pathname === '/api/evaluation' && req.method === 'GET') {
      const result = await getPublicEvaluation({ token: requestUrl.searchParams.get('token') });
      send(res, result.status, result.payload);
      return;
    }

    if (requestUrl.pathname === '/api/evaluation' && req.method === 'POST') {
      let raw = '';
      for await (const chunk of req) raw += chunk;
      let parsed = {};
      try {
        parsed = raw.trim() ? JSON.parse(raw) : {};
      } catch (_) {
        send(res, 400, { error: 'Invalid JSON request body.' });
        return;
      }
      const result = parsed?.action === 'verify'
        ? await verifyPublicEvaluationAccess({ body: parsed })
        : await submitPublicEvaluation({ body: parsed });
      send(res, result.status, result.payload);
      return;
    }

    send(res, 404, { error: 'Not found.' });
  } catch (error) {
    send(res, 500, {
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

server.listen(port, host, () => {
  console.log(`Practicum Connect local API running at http://${host}:${port}`);
  console.log('Available routes: /api/coordinator-approval, /api/staff-claims and /api/evaluation');
  console.log('Keep this terminal open while testing privileged/local API workflows.');
});
