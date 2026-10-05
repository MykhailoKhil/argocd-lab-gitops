// T16: steady background traffic THROUGH TRAEFIK, so it is split by the canary weights
// exactly like real users. Feeds the Prometheus metrics the AnalysisTemplate looks at.
import http from 'k6/http';

const HOST = __ENV.HOST;                 // e.g. demo-dev.localtest.me (routing is by Host header)
const RATE = parseInt(__ENV.RATE || '10'); // requests per second

export const options = {
  insecureSkipTLSVerify: true,           // lab CA is not in the k6 image's trust store
  discardResponseBodies: true,
  scenarios: {
    steady: {
      executor: 'constant-arrival-rate',
      rate: RATE,
      timeUnit: '1s',
      duration: '24h',                   // the Deployment restarts it afterwards
      preAllocatedVUs: 5,
      maxVUs: 50,
    },
  },
};

export default function () {
  http.get('https://traefik.kube-system.svc/', { headers: { Host: HOST } });
}
