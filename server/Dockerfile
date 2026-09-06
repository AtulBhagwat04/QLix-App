# Production Build Stage
FROM node:20-slim

WORKDIR /app

# Copy package descriptors and lockfiles
COPY package*.json ./

# Install dependencies including production locks
RUN npm install --omit=dev

# Copy database schema file required by sqlite/mongodb bridge
COPY schema.sql ./

# Copy application source code
COPY src/ ./src/

# Expose HTTP Port
EXPOSE 3000 10000

ENV NODE_ENV=production

# Run node entrypoint server.js
CMD ["node", "src/server.js"]

