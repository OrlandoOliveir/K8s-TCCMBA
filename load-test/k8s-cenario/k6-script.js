import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '60s', target: 50 },
    { duration: '120s', target: 100 },
    { duration: '30s', target: 0 }
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.01']
  }
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:30080';

export default function () {
  const res = http.get(`${BASE_URL}/clients`);

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
