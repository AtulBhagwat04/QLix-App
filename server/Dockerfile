# Production Build Stage
FROM node:18-alpine

WORKDIR /app

# Copy package descriptors and lockfiles
COPY package*.json ./

# Install dependencies including production locks
RUN npm ci --only=production

# Copy application source code
COPY src/ ./src/

# Expose default HTTP Port
EXPOSE 3000

ENV NODE_ENV=production

# Run node entrypoint server.js
CMD ["node", "src/server.js"]
