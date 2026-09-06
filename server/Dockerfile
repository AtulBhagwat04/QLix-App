# Build Stage - compile native C/C++ dependencies (sqlite3) against the container's glibc
FROM node:20-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev --build-from-source=sqlite3

# Production Runtime Stage
FROM node:20-slim

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
COPY schema.sql ./
COPY src/ ./src/

EXPOSE 3000 10000

ENV NODE_ENV=production

CMD ["node", "src/server.js"]

