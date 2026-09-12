// Distributed tracing so "why did this request fail" is one trace, not three separate logs.

const AWSXRay = require('aws-xray-sdk-core');
const AWSXRayExpress = require('aws-xray-sdk-express');

AWSXRay.config([AWSXRay.plugins.ECSPlugin]);
AWSXRay.captureHTTPsGlobal(require('http'));
AWSXRay.captureHTTPsGlobal(require('https'));

function instrumentExpressApp(app) {
  // Opens a trace segment per incoming request, tagged with the service name.
  app.use(AWSXRayExpress.openSegment('saas-platform'));

  app.use((req, res, next) => {
    const segment = AWSXRay.getSegment();
    segment.addAnnotation('route', req.path);
    segment.addAnnotation('user_id', req.user ? req.user.id : 'anonymous');
    next();
  });

  return app;
}

function closeExpressApp(app) {
  // Must be registered after all routes — closes the trace segment.
  app.use(AWSXRayExpress.closeSegment());
  return app;
}

module.exports = { instrumentExpressApp, closeExpressApp };
