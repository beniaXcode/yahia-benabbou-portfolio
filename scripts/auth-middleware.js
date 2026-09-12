// Validates an OAuth 2.0/OIDC bearer token at the API entry point and enforces role-based
// authorization per route, so no individual service reimplements its own auth check.

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

const client = jwksClient({
  jwksUri: process.env.OIDC_JWKS_URI,
  cache: true,
  rateLimit: true,
});

function getSigningKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) return callback(err);
    callback(null, key.getPublicKey());
  });
}

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: 'missing bearer token' });
  }

  jwt.verify(token, getSigningKey, { algorithms: ['RS256'] }, (err, decoded) => {
    if (err) {
      return res.status(401).json({ error: 'invalid or expired token' });
    }
    req.user = { id: decoded.sub, roles: decoded.roles || [] };
    next();
  });
}

function requireRole(role) {
  return (req, res, next) => {
    if (!req.user || !req.user.roles.includes(role)) {
      return res.status(403).json({ error: 'insufficient role for this action' });
    }
    next();
  };
}

// CSRF protection for state-changing routes — double-submit cookie pattern.
function requireCsrfToken(req, res, next) {
  const headerToken = req.headers['x-csrf-token'];
  const cookieToken = req.cookies && req.cookies['csrf-token'];
  if (!headerToken || !cookieToken || headerToken !== cookieToken) {
    return res.status(403).json({ error: 'csrf token missing or mismatched' });
  }
  next();
}

module.exports = { requireAuth, requireRole, requireCsrfToken };
