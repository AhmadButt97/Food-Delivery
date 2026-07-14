# ---- Stage 1: Build dependencies ----
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

# ---- Stage 2: Production image ----
FROM node:20-alpine

WORKDIR /app

# Create a non-root group and user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only what's needed from the builder stage
COPY --from=builder /app /app

# Ensure appuser owns the app files (needed for uploads/ writes)
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

EXPOSE 4000

CMD ["node", "server.js"]
