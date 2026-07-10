# Use official Node.js LTS image
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Copy package files first (better layer caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the frontend source code
COPY . .

# Expose Vite's dev server port
EXPOSE 5173

# Run Vite dev server, bound to all interfaces so it's reachable from outside the container
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
