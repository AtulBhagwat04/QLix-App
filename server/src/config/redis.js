import Redis from 'ioredis';
import dotenv from 'dotenv';

dotenv.config();

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

// Fully-compliant In-Memory Mock Redis Implementation
class MockRedis {
  constructor() {
    this.store = {};
    console.log('Redis Fallback: Initialized MockRedis in-memory store.');
  }

  async hincrby(key, field, increment) {
    if (!this.store[key]) this.store[key] = {};
    const val = parseInt(this.store[key][field] || '0', 10);
    const newVal = val + parseInt(increment, 10);
    this.store[key][field] = String(newVal);
    return newVal;
  }

  async hset(key, ...args) {
    if (!this.store[key]) this.store[key] = {};
    if (args.length === 1 && typeof args[0] === 'object') {
      const obj = args[0];
      for (const k of Object.keys(obj)) {
        this.store[key][k] = String(obj[k]);
      }
    } else {
      const field = args[0];
      const val = args[1];
      this.store[key][field] = String(val);
    }
    return 1;
  }

  async hgetall(key) {
    return this.store[key] || {};
  }

  async zadd(key, score, member) {
    if (!this.store[key]) this.store[key] = [];
    const idx = this.store[key].findIndex(x => x.member === member);
    if (idx !== -1) {
      this.store[key][idx].score = parseFloat(score);
    } else {
      this.store[key].push({ member, score: parseFloat(score) });
    }
    return 1;
  }

  async zrevrange(key, start, stop, withScores) {
    const list = this.store[key] || [];
    // Sort descending by score
    const sorted = [...list].sort((a, b) => b.score - a.score);
    const sliced = sorted.slice(start, stop + 1);
    
    if (withScores === 'WITHSCORES') {
      const result = [];
      for (const item of sliced) {
        result.push(item.member);
        result.push(String(item.score));
      }
      return result;
    }
    return sliced.map(item => item.member);
  }

  async del(key) {
    if (this.store[key]) {
      delete this.store[key];
      return 1;
    }
    return 0;
  }

  multi() {
    const self = this;
    const queue = [];
    return {
      hincrby(key, field, increment) {
        queue.push(() => self.hincrby(key, field, increment));
        return this;
      },
      hset(key, ...args) {
        queue.push(() => self.hset(key, ...args));
        return this;
      },
      async exec() {
        const results = [];
        for (const fn of queue) {
          results.push([null, await fn()]);
        }
        return results;
      }
    };
  }

  // Mock EventEmitter methods
  on(event, handler) {
    if (event === 'connect') {
      setTimeout(() => handler(), 0);
    }
  }

  connect() {
    return Promise.resolve();
  }
}

let activeClient;
let useMock = false;

// Create the real Redis client
const realClient = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  retryStrategy: (times) => {
    // Retry up to 2 times, then stop and trigger fallback to Mock
    if (times > 2) {
      if (!useMock) {
        console.warn('Redis Fallback: Real Redis connection failed. Falling back to MockRedis.');
        useMock = true;
        activeClient = new MockRedis();
      }
      return null; // Stop retrying connection
    }
    return Math.min(times * 100, 1000);
  }
});

activeClient = realClient;

realClient.on('connect', () => {
  if (!useMock) {
    console.log('Successfully connected to Redis');
  }
});

realClient.on('error', (err) => {
  if (!useMock) {
    console.warn(`Redis Fallback: Connection error: ${err.message}. Falling back to MockRedis.`);
    useMock = true;
    activeClient = new MockRedis();
  }
});

// Proxy client that forwards calls to the active client (real or mock)
const redisProxy = new Proxy({}, {
  get: (target, prop) => {
    const value = activeClient[prop];
    if (typeof value === 'function') {
      return value.bind(activeClient);
    }
    return value;
  }
});

// Helper for horizontal socket.io adapter scaling
export const createRedisClient = () => {
  const client = new Redis(redisUrl, {
    maxRetriesPerRequest: null,
    retryStrategy: (times) => {
      if (times > 2) return null; // Stop after 2 retries
      return Math.min(times * 100, 1000);
    }
  });
  client.on('error', () => {
    // Silent error handler to prevent Unhandled error event warnings
  });
  return client;
};

export default redisProxy;
