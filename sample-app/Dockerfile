# Multi-stage secure non-root Dockerfile for sample microservice
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

FROM node:20-alpine

WORKDIR /usr/src/app

# Create non-root user and group
RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -s /bin/sh -D appuser && \
    chown -R appuser:appgroup /usr/src/app

COPY --from=builder --chown=appuser:appgroup /usr/src/app ./

# Enforce non-root execution
USER 10001

EXPOSE 3000

ENV NODE_ENV=production \
    PORT=3000

CMD ["node", "server.js"]
