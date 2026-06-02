import http from 'http';
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import app from './app.js';
import { createRedisClient } from './config/redis.js';
import registerSocketHandlers from './sockets/socketHandler.js';
import db from './config/db.js';

const PORT = process.env.PORT || 3000;

const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: '*', // Customize for production
    methods: ['GET', 'POST'],
  },
});

// Configure horizontal scaling adapter via Redis Pub/Sub
try {
  const pubClient = createRedisClient();
  const subClient = createRedisClient();

  Promise.all([pubClient.connect(), subClient.connect()]).then(() => {
    io.adapter(createAdapter(pubClient, subClient));
    console.log('Horizontal scaling Socket.io Redis adapter connected');
  }).catch((err) => {
    console.warn('Redis adapter connections failed, falling back to local memory sockets:', err.message);
  });
} catch (e) {
  console.warn('Failed to construct Redis clients for Socket.io adapter:', e.message);
}

// Bind Websocket events handlers
registerSocketHandlers(io);

// Database connection validation before binding
const startServer = async () => {
  try {
    const dbTest = await db.query('SELECT NOW()');
    console.log(`PostgreSQL Pool connected successfully at ${dbTest.rows[0].now}`);

    server.listen(PORT, () => {
      console.log(`QLix Backend Server running in ${process.env.NODE_ENV || 'development'} mode on port ${PORT}`);
    });
  } catch (error) {
    console.error('Fatal: Database connection failed. Server not started.', error.message);
    process.exit(1);
  }
};

startServer();

// Handle graceful shutdown
const shutdown = () => {
  console.log('Received kill signal, shutting down gracefully...');
  server.close(async () => {
    console.log('HTTP server closed.');
    try {
      await db.pool.end();
      console.log('PostgreSQL pool terminated.');
      process.exit(0);
    } catch (err) {
      console.error('Error during database pool shutdown:', err);
      process.exit(1);
    }
  });
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
