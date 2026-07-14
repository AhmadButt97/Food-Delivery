# ---- Stage 1: Build the React app ----
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# ---- Stage 2: Serve the built app ----
FROM node:20-alpine

WORKDIR /app

# Install a lightweight static file server
RUN npm install -g serve

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only the built output from Stage 1
COPY --from=builder /app/dist /app/dist

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 5173

CMD ["serve", "-s", "dist", "-l", "5173"]
