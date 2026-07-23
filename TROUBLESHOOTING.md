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




---

# Troubleshooting Log — Task 7: Jenkins CI/CD Pipeline with GitHub Webhook

## 1. Java Package Name Mismatch on Amazon Linux
**Issue:** Installing Java for Jenkins failed with `No match for argument: java-17-openjdk` on Amazon Linux.
**Cause:** Amazon Linux uses its own OpenJDK build under a different package name than generic RHEL/CentOS repos.
**Solution:** Installed `java-17-amazon-corretto` instead, Amazon's own OpenJDK distribution.

## 2. "Pipeline script from SCM" Missing from Jenkins UI
**Issue:** The Pipeline job configuration only showed "Pipeline script" as an option, with no way to pull the pipeline definition from GitHub.
**Cause:** Required Pipeline plugins (workflow-scm-step, workflow-multibranch, workflow-job) were installed but not yet fully activated.
**Solution:** Restarted Jenkins after plugin installation and did a hard browser refresh, which revealed the missing option.

## 3. IPv6 Connectivity Causing Docker Hub Push Failures
**Issue:** Docker image pushes to Docker Hub intermittently failed mid-transfer with `connect: connection refused` errors.
**Cause:** The host had no working IPv6 connectivity, but DNS resolution for Docker Hub returned IPv6 addresses first. Every request attempted several failing IPv6 connections before falling back to IPv4, and this pattern eventually caused a dropped connection during a long multi-layer push.
**Solution:** Disabled IPv6 in the Docker daemon configuration (`/etc/docker/daemon.json` with `"ipv6": false`) and restarted Docker, forcing all connections to use IPv4 directly.

## 4. Local Git Repository Corruption
**Issue:** Local Git commands began failing with `fatal: bad object HEAD` and multiple `object file ... is empty` errors.
**Cause:** Git object files in `.git/objects/` became corrupted, likely due to an interrupted disk write or VM issue.
**Solution:** Since all work had been regularly pushed to GitHub, the corrupted local folder was safely renamed and a fresh clone was pulled from the remote repository, with zero data loss.

## 5. GitHub Webhook Unreachable via Private IP
**Issue:** The GitHub webhook consistently failed delivery when configured with the Jenkins server's local network IP address (e.g. `192.168.x.x`).
**Cause:** Private IP addresses are not routable from the public internet, so GitHub's servers had no way to reach the Jenkins instance.
**Solution:** Used ngrok to create a secure public tunnel to the local Jenkins instance, and updated the webhook's Payload URL to the ngrok-provided public HTTPS URL, which resolved delivery immediately.

## Outcome
Successfully configured a working Jenkins CI/CD pipeline that automatically builds and pushes Docker images for backend, frontend, and admin services to Docker Hub, GitHub Container Registry, and AWS ECR on every push to the `feature/ahmadbutt` branch, triggered via GitHub webhook.


# Task NO 8  

Troubleshooting & Documentation

During the implementation of the CI/CD pipeline, several issues were encountered related to Docker, Jenkins, Docker Hub, Docker Compose, and GitHub webhooks. Docker Hub authentication problems were resolved by configuring credentials securely in Jenkins. Network and DNS issues causing Docker image push failures were fixed by updating the DNS configuration.

While deploying the application, Docker Compose was unable to pull images because of incorrect image names and tags. The issue was resolved by verifying the Docker Hub repositories and updating the image references in the docker-compose.yml file.

The backend service initially failed to connect to MongoDB due to container hostname resolution problems. This was fixed by connecting all services to the same Docker network and updating the MongoDB connection string.

GitHub webhook integration stopped working when the ngrok session expired. The webhook was restored by reconfiguring ngrok and updating the webhook URL in the GitHub repository settings.

To avoid storage issues on the Jenkins server, a cleanup stage was added to remove local Docker images after they were pushed to Docker Hub. Testing confirmed that all containers were successfully deployed using Docker Compose and that communication between the frontend, backend, admin panel, and MongoDB was working correctly.

The project followed best practices, including secure credential management, automated CI/CD workflows, Docker image optimization, Git branching strategies, and comprehensive documentation of issues and solutions.

# TROUBLESHOOTING.md

# Task 9 - Kubernetes Deployment using kubeadm

## Project Overview

The application was deployed on a Kubernetes cluster created using **kubeadm** on an AWS EC2 instance. The deployment includes frontend and backend services using Kubernetes Deployments and Services.

---

# Deployment Steps

1. Created a Kubernetes cluster using kubeadm.
2. Verified the cluster status using:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```
3. Created Deployment manifests for:
   - Frontend
   - Backend
4. Created Service manifests:
   - Frontend (NodePort)
   - Backend (ClusterIP)
5. Applied all manifests:
   ```bash
   kubectl apply -f k8s/
   ```
6. Verified Deployments, Pods, and Services.
7. Tested frontend and backend communication.

---

# Issues Encountered

## Issue 1: Pods Not Starting

### Symptoms

Pods remained in the `Pending` or `ContainerCreating` state.

### Possible Cause

- Kubernetes node was not ready.
- Required images were still downloading.
- Resource constraints on the node.

### Resolution

Checked node and pod status.

```bash
kubectl get nodes
kubectl get pods
kubectl describe pod <pod-name>
```

Waited for the images to download and ensured the node status was **Ready**.

---

## Issue 2: ImagePullBackOff

### Symptoms

Pods showed:

```
ImagePullBackOff
```

### Cause

Docker image name or tag was incorrect, or the image was unavailable.

### Resolution

- Verified the image existed on Docker Hub.
- Corrected the image name in the Deployment manifest.
- Reapplied the manifest.

```bash
kubectl apply -f backend-deployment.yaml
kubectl apply -f frontend-deployment.yaml
```

---

## Issue 3: CrashLoopBackOff

### Symptoms

Pods restarted repeatedly.

### Cause

Application configuration or environment variables were incorrect.

### Resolution

Checked the logs.

```bash
kubectl logs <pod-name>
```

Verified the environment variables and updated the Deployment manifest if required.

---

## Issue 4: Frontend Not Accessible

### Symptoms

The application could not be accessed from the browser.

### Cause

Frontend Service was not exposed correctly.

### Resolution

Verified the Service configuration.

```bash
kubectl get svc
```

Confirmed that the frontend Service type was **NodePort** and accessed the application using:

```
http://<EC2-PUBLIC-IP>:<NodePort>
```

---

## Issue 5: Frontend Could Not Communicate with Backend

### Symptoms

Frontend loaded but API requests failed.

### Cause

Incorrect backend Service name or Service configuration.

### Resolution

Verified the backend Service.

```bash
kubectl get svc
```

Ensured the frontend used the Kubernetes Service name instead of a Pod IP or localhost.

---

# Verification Commands

Verify cluster:

```bash
kubectl cluster-info
kubectl get nodes
```

Verify Deployments:

```bash
kubectl get deployments
```

Verify Pods:

```bash
kubectl get pods
```

Describe Pods:

```bash
kubectl describe pod <pod-name>
```

View Pod Logs:

```bash
kubectl logs <pod-name>
```

Verify Services:

```bash
kubectl get svc
```

---

# Best Practices

- Organize Kubernetes manifests inside a dedicated `k8s/` directory.
- Use labels and selectors consistently.
- Use **ClusterIP** for internal services.
- Use **NodePort** only for external access in development environments.
- Verify Pods and Services after every deployment.
- Check pod logs before modifying manifests.
- Keep Docker images updated before redeploying.

---

# Conclusion

The application was successfully deployed on a Kubernetes cluster created with **kubeadm**. Deployments, Pods, and Services were verified, and communication between the frontend and backend was successfully established.
