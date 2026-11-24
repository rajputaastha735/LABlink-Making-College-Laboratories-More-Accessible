# Multi-stage Dockerfile for Google Cloud Run (LabLink)

# Stage 1: Build the client assets
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package descriptors
COPY package.json package-lock.json ./

# Install all dependencies (including devDependencies required for Vite build)
RUN npm ci

# Copy application source files
COPY . .

# Build the frontend client with Vite (outputs to dist/)
RUN npm run build

# Stage 2: Slim runtime container with production dependencies only
FROM node:20-alpine AS runtime

# Set production environment
ENV NODE_ENV=production
ENV PORT=8080
ENV HOST=0.0.0.0

WORKDIR /app

# Copy package descriptors for production install
COPY package.json package-lock.json ./

# Install ONLY production dependencies and clear npm cache to keep image slim
RUN npm ci --omit=dev && npm cache clean --force

# Copy built frontend assets from builder stage
COPY --from=builder /app/dist ./dist

# Copy backend server code and configuration
COPY --from=builder /app/server ./server
COPY --from=builder /app/package.json ./package.json

# Ensure ownership by the built-in non-root node user
RUN chown -R node:node /app

# Switch to non-root user
USER node

# Expose default Cloud Run container port
EXPOSE 8080

# Start Express server serving API endpoints and static SPA
CMD ["node", "server/index.js"]

# Build stage
FROM node:24-slim AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

RUN npm run build

# Production stage
FROM node:24-slim

WORKDIR /app

ENV NODE_ENV=production

COPY package*.json ./

RUN npm ci --omit=dev

COPY --from=build /app/server ./server
COPY --from=build /app/dist ./dist

EXPOSE 8080

CMD ["npm", "start"]

