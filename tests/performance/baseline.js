// Performance Baseline Tests for Cinema Microservices
// Usage: k6 run tests/performance/baseline.js
// With options: k6 run --vus 50 --duration 2m tests/performance/baseline.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Custom metrics
const movieLatency = new Trend('movie_latency', true);
const showtimeLatency = new Trend('showtime_latency', true);
const seatLatency = new Trend('seat_latency', true);
const bookingLatency = new Trend('booking_latency', true);
const errorRate = new Rate('errors');
const requestCount = new Counter('requests');

// Configuration
const BASE_URLS = {
  movie: __ENV.MOVIE_URL || 'http://localhost:8000',
  showtime: __ENV.SHOWTIME_URL || 'http://localhost:3003',
  seat: __ENV.SEAT_URL || 'http://localhost:3004',
  booking: __ENV.BOOKING_URL || 'http://localhost:8082',
  user: __ENV.USER_URL || 'http://localhost:8004',
};

export const options = {
  scenarios: {
    // Smoke test - verify system works
    smoke: {
      executor: 'constant-vus',
      vus: 1,
      duration: '10s',
      tags: { scenario: 'smoke' },
    },
    // Load test - normal traffic
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },  // Ramp up
        { duration: '1m', target: 10 },   // Steady state
        { duration: '30s', target: 0 },   // Ramp down
      ],
      startTime: '15s', // Start after smoke test
      tags: { scenario: 'load' },
    },
  },
  thresholds: {
    // Response time thresholds
    movie_latency: ['p(95)<200', 'p(99)<500'],
    showtime_latency: ['p(95)<200', 'p(99)<500'],
    seat_latency: ['p(95)<250', 'p(99)<500'],

    // Error rate threshold
    errors: ['rate<0.01'], // Less than 1% errors

    // HTTP-level thresholds
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
};

// Helper function to make request and record metrics
function makeRequest(url, metricTrend, name) {
  const start = Date.now();
  const res = http.get(url, { tags: { name } });
  const duration = Date.now() - start;

  metricTrend.add(duration);
  requestCount.add(1);

  const success = check(res, {
    [`${name} status is 200`]: (r) => r.status === 200,
    [`${name} response time < 500ms`]: (r) => r.timings.duration < 500,
  });

  if (!success) {
    errorRate.add(1);
  }

  return res;
}

export default function () {
  // Simulate user browsing flow
  group('Browse Movies', () => {
    const res = makeRequest(`${BASE_URLS.movie}/movies`, movieLatency, 'GET /movies');

    // Parse response to get movie ID for next request
    if (res.status === 200) {
      try {
        const data = JSON.parse(res.body);
        if (data.movies && data.movies.length > 0) {
          const movieId = data.movies[0].id;
          // Get single movie details
          makeRequest(`${BASE_URLS.movie}/movies/${movieId}`, movieLatency, 'GET /movies/:id');
        }
      } catch (e) {
        // Ignore parse errors
      }
    }
  });

  sleep(0.5);

  group('Browse Showtimes', () => {
    makeRequest(`${BASE_URLS.showtime}/showtimes`, showtimeLatency, 'GET /showtimes');
  });

  sleep(0.5);

  group('Check Seat Availability', () => {
    // Use a known showtime ID for testing
    const showtimeId = __ENV.SHOWTIME_ID || 'sht_001';
    makeRequest(
      `${BASE_URLS.seat}/seats/availability?showtime_id=${showtimeId}`,
      seatLatency,
      'GET /seats/availability'
    );
  });

  sleep(1);
}

// Lifecycle hooks
export function setup() {
  console.log('Starting performance baseline test...');
  console.log('Movie Service:', BASE_URLS.movie);
  console.log('Showtime Service:', BASE_URLS.showtime);
  console.log('Seat Service:', BASE_URLS.seat);

  // Verify services are healthy
  const movieHealth = http.get(`${BASE_URLS.movie}/ping`);
  if (movieHealth.status !== 200) {
    throw new Error('Movie service not healthy');
  }

  return { startTime: Date.now() };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`Test completed in ${duration.toFixed(2)}s`);
}

// Summary handler for custom output
export function handleSummary(data) {
  const summary = {
    timestamp: new Date().toISOString(),
    duration: data.state.testRunDurationMs,
    metrics: {
      movie_latency_p95: data.metrics.movie_latency?.values?.['p(95)'] || 0,
      showtime_latency_p95: data.metrics.showtime_latency?.values?.['p(95)'] || 0,
      seat_latency_p95: data.metrics.seat_latency?.values?.['p(95)'] || 0,
      error_rate: data.metrics.errors?.values?.rate || 0,
      total_requests: data.metrics.requests?.values?.count || 0,
    },
    thresholds: {
      passed: Object.values(data.thresholds || {}).every(t => t.ok),
    },
  };

  return {
    'tests/test-results/performance-baseline.json': JSON.stringify(summary, null, 2),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

// Text summary helper
function textSummary(data, options) {
  const lines = [
    '',
    '='.repeat(60),
    '  PERFORMANCE BASELINE SUMMARY',
    '='.repeat(60),
    '',
  ];

  if (data.metrics.movie_latency) {
    lines.push(`  Movie Service (p95):    ${data.metrics.movie_latency.values['p(95)'].toFixed(2)}ms`);
  }
  if (data.metrics.showtime_latency) {
    lines.push(`  Showtime Service (p95): ${data.metrics.showtime_latency.values['p(95)'].toFixed(2)}ms`);
  }
  if (data.metrics.seat_latency) {
    lines.push(`  Seat Service (p95):     ${data.metrics.seat_latency.values['p(95)'].toFixed(2)}ms`);
  }

  lines.push('');
  lines.push(`  Total Requests: ${data.metrics.requests?.values?.count || 0}`);
  lines.push(`  Error Rate:     ${((data.metrics.errors?.values?.rate || 0) * 100).toFixed(2)}%`);
  lines.push('');
  lines.push('='.repeat(60));
  lines.push('');

  return lines.join('\n');
}
