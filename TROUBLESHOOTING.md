# Troubleshooting Log — Task 3: Dockerizing TOMATO Food Delivery App

## 1. MongoDB Atlas SRV DNS Resolution Error
**Issue:** Connecting the backend to MongoDB Atlas via `mongodb+srv://` threw:

**Cause:** Likely a malformed cluster hostname / DNS SRV lookup mismatch inside the VirtualBox VM's networking.
**Solution:** Switched to running MongoDB locally in a Docker container instead of Atlas, avoiding SRV DNS lookups entirely.

## 2. `.dockerignore` Excluding `.env`
**Issue:** Initially added `.env` to `.dockerignore`, which meant environment variables (JWT_SECRET, MONGO_URL, etc.) were never copied into the backend image, causing runtime crashes.
**Solution:** Removed `.env` from `.dockerignore`, keeping only `node_modules` excluded.

## 3. Host `mongod` Service Holding Port 27017
**Issue:** `docker compose up` failed with:

**Cause:** A native `mongod` service was already running directly on the VM (installed earlier for local testing), occupying port 27017 before Docker could bind it.
**Solution:** Stopped and disabled the native service:
```bash
sudo systemctl stop mongod
sudo systemctl disable mongod
sudo systemctl mask mongod
```

## 4. MongoDB Container Not Attached to Docker Network
**Issue:** Backend logs showed:


even though the `mongodb` container was running.
**Cause:** The `mongodb` container had lost its attachment to the `food-delivery_default` Docker network (likely from an earlier failed startup due to the port conflict above).
**Solution:** Manually reconnected it:
```bash
docker network connect food-delivery_default mongodb
```
Confirmed via `docker inspect mongodb` and restarted the backend container to re-establish the connection.

## 5. Stale Hardcoded Production URLs
**Issue:** `frontend/src/context/StoreContext.jsx` and `backend/controllers/orderController.js` still pointed to the original developer's live Render URLs instead of local containers, which would have broken API calls and Stripe checkout redirects.
**Solution:** Updated all references to use `http://localhost:4000` (backend) and `http://localhost:5173` (frontend) to match the local Docker Compose setup.

## Outcome
After resolving the above, `docker compose up -d --build` successfully starts all four services (MongoDB, backend, frontend, admin), with confirmed connectivity across:
- Backend → MongoDB (`{"success":true,"data":[]}` from `/api/food/list`)
- Admin → Backend → MongoDB (adding a food item via Admin panel)
- Frontend → Backend → MongoDB (new item visible on homepage)




---

# Troubleshooting Log — Task 5: Multi-Stage, Rootless Docker Images & Registry Push

## Summary
This task went smoothly overall, largely due to networking and permission issues already resolved during Task 3. Key implementation notes below.

## 1. Rootless Container Permissions
**Consideration:** Switching containers to run as a non-root user (`appuser`) required explicitly setting file ownership before switching users.
**Solution:** Added `RUN chown -R appuser:appgroup /app` before the `USER appuser` instruction in each Dockerfile, ensuring the non-root user has write access to necessary directories (e.g. `uploads/` in the backend).

## 2. Multi-Stage Build Image Size Reduction
**Implementation:** Split each Dockerfile into a `builder` stage (installs dependencies, builds the app) and a slim final stage that only copies the necessary build output (`dist/` for frontend/admin, `node_modules` + source for backend).
**Result:** Meaningfully smaller final images with no dev dependencies or build tools included, reducing attack surface.

## 3. Registry Authentication
**Implementation:** Authenticated separately with three registries — Docker Hub (`docker login`), GitHub Container Registry (`docker login ghcr.io` with a Personal Access Token), and AWS ECR (`aws ecr get-login-password | docker login`).
**Note:** Each registry requires its own login/auth flow and image tag format (e.g. `ghcr.io/<username>/<image>`, `<account-id>.dkr.ecr.<region>.amazonaws.com/<image>`), so images had to be tagged three separate times per service before pushing.

## Outcome
Successfully built hardened, multi-stage, rootless images for backend, frontend, and admin services, and pushed all three to Docker Hub, GHCR, and AWS ECR. Verified full-stack functionality remained intact after switching to the new images.
