// T16: a short test aimed DIRECTLY at the canary Service (not through Traefik), run by the
// AnalysisRun as a Job. k6 exits non-zero when a threshold fails -> Job fails ->
// the analysis metric fails -> Argo Rollouts aborts the release.
import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.TARGET;             // http://demo-api-canary.<namespace>.svc

export const options = {
  scenarios: {
    canary: {
      executor: 'constant-arrival-rate',
      rate: 20,
      timeUnit: '1s',
      duration: '60s',
      preAllocatedVUs: 10,
      maxVUs: 50,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],                 // < 1% errors
    http_req_duration: ['p(95)<300'],               // p95 < 300 ms
    checks: ['rate>0.99'],
  },
};

export default function () {
  const res = http.get(`${TARGET}/`);
  check(res, {
    'status is 200': (r) => r.status === 200,
    'has version': (r) => r.body && r.body.includes('"version"'),
  });
}
