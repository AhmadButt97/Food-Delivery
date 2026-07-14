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

RUN npm install -g serve

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/dist /app/dist

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 5173

CMD ["serve", "-s", "dist", "-l", "5173"]
