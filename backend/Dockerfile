FROM node:18-alpine

# Install OpenSSL and other dependencies
RUN apk add --no-cache openssl

WORKDIR /app

# Install dependencies (including devDependencies for TypeScript compilation)
COPY package*.json ./
RUN npm ci

# Copy source code
COPY . .

# Create scripts directory and copy scripts
RUN mkdir -p scripts
COPY scripts/ ./scripts/
RUN chmod +x scripts/*.sh || true

# VERSION file will be copied from build context

# Generate Prisma Client
RUN npx prisma generate

# Build TypeScript
RUN npm run build

# Remove devDependencies to reduce image size
RUN npm prune --production

# Expose port
EXPOSE 3002

# Start command
CMD ["node", "dist/server.js"] 