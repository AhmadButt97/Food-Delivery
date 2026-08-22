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


---

# Troubleshooting Log — Task 9: Kubernetes Deployment (kubeadm)

## 1. Used kubeadm Instead of Kind
**Deviation:** The task recommended Kind (Kubernetes in Docker) for a multi-node local cluster. Since a working kubeadm cluster already existed on the VM, that was used instead.
**Reasoning:** kubeadm provides a more production-representative cluster setup, and functionally the manifests/deployment steps are identical regardless of how the underlying cluster was created.

## 2. Single-Node Cluster Instead of Control-Plane + 2 Workers
**Issue:** Only one VM was available, so a true multi-node cluster (1 control-plane + 2 workers) wasn't feasible without additional VMs.
**Solution:** Removed the default `NoSchedule` taint from the control-plane node so it could run application workloads, effectively acting as both control-plane and worker.

## 3. Docker Removed as Kubernetes Container Runtime (dockershim)
**Issue:** Attempted to use Docker directly as the Kubernetes container runtime.
**Cause:** Kubernetes removed native Docker support (dockershim) starting v1.24; the cluster was running v1.29.
**Solution:** Installed `cri-dockerd` as a shim layer, allowing kubelet to communicate with Docker Engine via the CRI interface, while containerd continues to run underneath Docker as its backend.

## 4. CoreDNS Pods Stuck in ContainerCreating — CNI Conflict
**Issue:** After installing Flannel as the CNI plugin, CoreDNS pods remained stuck, with errors referencing a "calico" plugin failing with expired/invalid certificates.
**Cause:** A stale Calico CNI configuration file was left in `/etc/cni/net.d/` from an earlier cluster setup attempt. Kubernetes was still picking up this leftover config instead of the newly installed Flannel config.
**Solution:** Removed the stale Calico config files from `/etc/cni/net.d/`, restarted containerd and kubelet, and deleted the stuck CoreDNS pods to force recreation. CoreDNS came up healthy afterward.

## Outcome
Deployed a single-node Kubernetes cluster (kubeadm + containerd/cri-dockerd + Flannel) running the food delivery application's backend, frontend, and database, all confirmed running and communicating correctly.

---

# Troubleshooting Log — Task 10: ConfigMaps, Secrets, and Persistent Storage

## 1. No Dynamic Storage Provisioner on Bare-Metal Cluster
**Issue:** A PersistentVolumeClaim for MongoDB's StatefulSet remained `Pending` indefinitely, with no PersistentVolume ever created.
**Cause:** Unlike cloud-managed clusters (EKS, GKE), a bare kubeadm cluster has no built-in storage provisioner to dynamically create PersistentVolumes.
**Solution:** Installed Rancher's `local-path-provisioner`, which dynamically provisions PVs backed by local directories on the VM's disk, and set it as the default StorageClass.

## 2. MongoDB Moved from Deployment to StatefulSet
**Reasoning:** A regular Deployment doesn't guarantee stable pod identity or a dedicated volume per pod — replacement pods could lose data continuity. Switched MongoDB to a StatefulSet with `volumeClaimTemplates`, giving it a stable hostname (`mongodb-0`) and a dedicated PVC that persists across pod restarts.

## Outcome
Database now runs as a StatefulSet with persistent storage backed by a locally-provisioned PV/PVC, configuration is managed via ConfigMaps and Secrets instead of hardcoded values, and all resources are deployed inside a dedicated namespace.

---

# Troubleshooting Log — Task 11: Resource Limits, Health Probes, HPA, and Load Testing

## 1. Metrics Server Required for HPA
**Issue:** HPA showed no CPU metrics / targets as `<unknown>` initially.
**Cause:** Kubernetes doesn't include a metrics pipeline by default — HPA requires metrics-server to read live CPU/memory usage.
**Solution:** Installed metrics-server and patched it with `--kubelet-insecure-tls`, since the cluster's kubelet certificates aren't signed by a recognized CA (expected on a local/self-managed cluster, not an issue on managed cloud clusters).

## 2. Resource Requests/Limits Tuning
**Consideration:** Initial CPU requests were set conservatively low, since HPA scaling is based on percentage of the *requested* CPU, not the limit — setting this value thoughtfully was necessary for the autoscaler to trigger at a realistic load level.

## 3. Load Testing and Scaling Verification
**Approach:** Used Apache Bench (`ab`) to generate concurrent load against the backend service, then monitored `kubectl get hpa -w` and `kubectl get pods -w` in parallel to observe replica count increasing as CPU utilization crossed the configured threshold.

## Outcome
Backend and frontend deployments now have defined resource requests/limits, liveness/readiness probes, and an active HorizontalPodAutoscaler. Load testing confirmed automatic scale-up under increased traffic and scale-down once load subsided.


---

# Troubleshooting Log — Task 12: NGINX Ingress Controller

## 1. Flannel CNI Transient Failure During Ingress Setup
**Issue:** Ingress admission webhook jobs (`ingress-nginx-admission-create`, `ingress-nginx-admission-patch`) initially failed pod sandbox creation with the same intermittent Flannel `subnet.env` error seen in earlier tasks.
**Solution:** Jobs eventually succeeded on retry once Flannel networking stabilized; no manual intervention was required this time, though the same fix (checking Flannel pod health, restarting if needed) applies if it recurs.

## 2. Backend Route Broken by Ingress Path Rewriting
**Issue:** Frontend was reachable through Ingress, but backend API requests returned "Cannot GET /food/list" instead of the expected JSON response.
**Cause:** The initial Ingress configuration used a `rewrite-target` annotation with regex capture groups, which stripped the `/api` prefix before forwarding requests to the backend service. Since the backend's Express routes are mounted at `/api/food/...`, the rewritten path no longer matched any route.
**Solution:** Removed the rewrite annotation and regex-based paths, using simple `Prefix` path matching instead so `/api/...` requests reach the backend with the path fully intact.

## Outcome
NGINX Ingress Controller successfully installed and configured to route `/api/*` traffic to the backend service and all other traffic to the frontend service, both accessible through a single Ingress endpoint (NodePort 32593). Verified frontend loads correctly and can successfully fetch data from the backend API through the Ingress.



---

# Troubleshooting Log — Task 13: Helm Chart Conversion

## 1. Default helm create Boilerplate Referenced Non-Existent Values
**Issue:** `helm lint` failed with a nil pointer error referencing `.Values.httpRoute.enabled`.
**Cause:** The default `NOTES.txt` generated by `helm create` referenced default scaffold values (httpRoute, service, ingress structure) that were removed when values.yaml was replaced with the application's own custom structure.
**Solution:** Replaced NOTES.txt with a simplified version referencing only the application's actual values.

## 2. Helm Refused to Adopt Pre-Existing Resources
**Issue:** `helm install` failed with an ownership metadata error on the `backend-secret` resource.
**Cause:** Resources originally created via raw `kubectl apply` (from Tasks 9-12) lack the Helm-specific labels/annotations Helm requires to manage a resource. Helm intentionally refuses to silently take over resources it didn't create, to prevent accidental conflicts.
**Solution:** Deleted the pre-existing raw-manifest resources (Secret, Deployments, Services, Ingress) before running `helm install`, allowing Helm to create fresh, properly-labeled versions. The MongoDB StatefulSet's PVC was preserved throughout, since deleting the StatefulSet does not delete its underlying PersistentVolumeClaim — confirming no data was lost during the migration to Helm.

## Outcome
Successfully converted all Kubernetes manifests (Deployments, Services, StatefulSet, Ingress, Secret, HPA) into a parameterized Helm chart. Verified the application deploys correctly via a single `helm install` command, with all configuration (image tags, replica counts, resource limits, credentials) externalized to values.yaml.



# Task 15 – Troubleshooting & Documentation

## Overview

This task implemented a CI/CD and GitOps workflow using **GitHub Actions, Docker Hub, ArgoCD, and ArgoCD Image Updater**.

> Note: The task originally specified Jenkins for CI, but GitHub Actions was used instead to build and push Docker images.

---

## Architecture

GitHub Repository
        |
        v
GitHub Actions
        |
        | Build Docker Images
        v
Docker Hub
        |
        | New Image Version
        v
ArgoCD Image Updater
        |
        | Update Helm Values
        v
Git Repository
        |
        v
ArgoCD
        |
        | Automatic Sync
        v
Kubernetes Cluster
        |
        v
Application Pods

---

# 1. GitHub Actions Used Instead of Jenkins

### Issue

The original task required Jenkins for the CI pipeline.

### Solution

GitHub Actions was used as the CI platform because the project repository is hosted on GitHub.

The GitHub Actions workflow was configured to:

- Checkout the application source code.
- Build Docker images.
- Authenticate with Docker Hub.
- Push the Docker images to Docker Hub.
- Use versioned image tags.

### Verification

The workflow was checked from:

```text
GitHub Repository
→ Actions
→ Workflow
→ Job

### Task no 16
Troubleshooting & Documentation

During the infrastructure provisioning and deployment of the Food Delivery application, several issues were identified and resolved. Initially, there were connectivity issues between the backend and MongoDB, which were resolved by correctly configuring the MongoDB service and connection string. Kubernetes storage also caused an issue where the MongoDB PVC remained in a Pending state because the required local-path StorageClass was not available. The StorageClass configuration was corrected so that the PVC could be provisioned successfully.

Another issue occurred when the MongoDB container image could not be pulled because the private EC2 instance had limited disk space. The instance had only an 8 GB root disk, and containerd and Docker were consuming most of the available space. This resulted in a no space left on device error while pulling the MongoDB image. The root EBS volume was increased to 30 GB, and the partition was expanded using growpart, providing enough storage for the Kubernetes workloads.

The Kubernetes Ingress setup also required troubleshooting. Initially, the application Ingress was configured with the traefik IngressClass while the NGINX Ingress Controller was being used. This caused NGINX to return a 404 Not Found response because it was not processing the application's Ingress resource. The IngressClass was changed from traefik to nginx, after which NGINX correctly routed requests to the application services.

Finally, AWS Application Load Balancer connectivity was configured and tested. The ALB initially reported the Kubernetes target as unhealthy. The issue was investigated by checking the target port, security-group rules, health-check configuration, and connectivity to the NGINX NodePort. A socat port-forwarding process was configured to forward traffic from the private EC2 port 32500 to the Kind Kubernetes node. The ALB health-check success codes were also changed to accept 200-499, allowing the NGINX 404 response during the connectivity test. After correcting the Ingress configuration and networking, the ALB successfully reached the Kubernetes application and the application became accessible through the ALB DNS.

These troubleshooting steps were documented to provide a reference for future infrastructure deployments, debugging, and maintenance.

# Task 18 - Kubernetes Application Monitoring

## Objective

Monitor the Kubernetes application running on an AWS EC2 instance using:

- AWS CloudWatch
- CloudWatch Agent
- CloudWatch Logs
- CloudWatch Metrics
- SNS
- Prometheus
- Grafana

## Architecture

EC2
|
+-- Kubernetes / Kind
|   |
|   +-- Food Delivery Application
|   |   +-- Backend
|   |   +-- Frontend
|   |   +-- MongoDB
|   |
|   +-- Prometheus
|   +-- Grafana
|
+-- CloudWatch Agent
    |
    +-- CloudWatch Logs
    +-- CloudWatch Metrics
    |
    +-- CloudWatch Alarms
            |
            +-- SNS
                |
                +-- Email

## CloudWatch

The Amazon CloudWatch Agent was installed on the EC2 instance.

The agent collects:

- EC2 CPU metrics
- EC2 memory metrics
- EC2 disk metrics
- Kubernetes application logs

Application logs collected from:

- Backend
- Frontend
- MongoDB

## CloudWatch Log Groups

The following log groups were created:

- /food-delivery/backend
- /food-delivery/frontend
- /food-delivery/mongodb

## Application Error Monitoring

A CloudWatch metric filter was configured for:

ERROR

The filter publishes the metric:

FoodDelivery/Application/BackendErrors

This metric can be used by a CloudWatch alarm.

## CloudWatch Alarms

Configured monitoring for:

- CPU usage
- Memory usage
- Application errors

SNS is used to send alarm notifications through email.

## Prometheus

Prometheus was installed using kube-prometheus-stack.

Prometheus collects Kubernetes metrics from:

- Kubernetes API server
- Kubelet
- Node Exporter
- kube-state-metrics
- Kubernetes workloads

## Grafana

Grafana was installed with kube-prometheus-stack.

Prometheus was configured as the Grafana data source.

Kubernetes dashboards were provisioned automatically.

Dashboards include:

- Kubernetes / API server
- Kubernetes / Kubelet
- Kubernetes / Networking / Cluster
- Kubernetes / Networking / Pod
- Kubernetes / Networking / Workload
- Kubernetes / Persistent Volumes
- Kubernetes resource dashboards

## Application Monitoring

The food-delivery namespace is visible in Grafana.

The namespace contains:

- backend
- frontend
- mongodb

Grafana displays Kubernetes performance and networking metrics for the application.

## Verification

Prometheus targets were checked from the Prometheus Targets page.

Grafana dashboards were checked for Kubernetes metrics.

CloudWatch metrics were checked from the AWS CloudWatch console.

CloudWatch log groups were verified for application logs.

## Troubleshooting

During setup, several issues were encountered and resolved:

1. Kubernetes Ingress was not directly reachable from the EC2 public IP.
2. Socat was configured to expose the Kind NodePort.
3. CloudWatch Agent was initially not installed.
4. CloudWatch Agent was installed and configured.
5. Kubernetes pod log paths inside the Kind node were identified.
6. CloudWatch log collection was configured using the Kind node log paths.
7. Grafana and Prometheus were exposed using port forwarding and SSH tunnels.

## Result

The Kubernetes application is monitored using both:

- AWS CloudWatch
- Prometheus + Grafana

CloudWatch provides centralized logs, EC2 metrics, alarms and SNS notifications.

Prometheus and Grafana provide detailed Kubernetes metrics and visualization.



# Task 19 - Deploying Dockerized Applications to AWS ECS

## Overview
Deployed a dockerized frontend (React/Vite) and backend (Node/Express) app to AWS ECS Fargate,
fronted by an Application Load Balancer, with a MongoDB sidecar container in the backend task.

## Steps Completed
1. Installed and configured AWS CLI, verified access via `aws sts get-caller-identity`
2. Created ECR repositories for backend and frontend
3. Built, tagged, and pushed Docker images to ECR
4. Created ECS task definitions:
   - Backend: includes a MongoDB sidecar container (same task, communicating over localhost via awsvpc mode)
   - Frontend: standalone container
5. Created networking: security group, Application Load Balancer, two target groups, listener + path-based routing rule (`/api/*` → backend, default → frontend)
6. Created ECS cluster and two Fargate services (backend-service, frontend-service)
7. Verified both services healthy in their target groups
8. Tested end-to-end via ALB DNS name

## Issues Encountered & Fixes

### Issue 1: Target groups not found when creating services
**Cause:** Steps were run out of order — target groups (Step 4) and the ALB (Step 3) hadn't
actually been created yet when referenced later, since earlier commands silently didn't
complete/weren't run.
**Fix:** Verified each resource's existence with `describe-*` commands before proceeding,
recreated the security group and ALB, then created target groups and listener in the correct order.

### Issue 2: curl to ALB DNS name hung / connection not established
**Cause:** The ALB and the ECS tasks shared a single security group (`ecs-tasks-sg`), which
only had inbound rules for ports 4000 and 5173 — never port 80. The ALB was silently dropping
inbound connections on port 80 from the internet.
**Fix:** Added an inbound rule for port 80 on the security group:
`aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 80 --cidr 0.0.0.0/0`

**Lesson for next time:** Use separate security groups — one for the ALB (open to internet on
80/443) and one for the ECS tasks (open only to the ALB's security group, not 0.0.0.0/0).
This is both more secure and would have surfaced this bug immediately during planning
rather than after deployment.

## Architecture
Internet → ALB (port 80) → Target Groups → ECS Fargate Tasks (awsvpc networking)
- `/` → frontend-tg → frontend-service (port 5173)
- `/api/*` → backend-tg → backend-service (port 4000, with MongoDB sidecar on 27017)

## Resources Created (torn down after task completion)
- ECS cluster: food-delivery-cluster
- ECS services: backend-service, frontend-service
- ALB: food-delivery-alb
- Target groups: backend-tg, frontend-tg
- Security group: ecs-tasks-sg
- Task definitions: food-delivery-backend, food-delivery-frontend


# Task 20 - EKS Production Deployment with Helm and ArgoCD

## Overview
Provisioned a production-style EKS cluster via Terraform, deployed a blue/green setup
using Helm charts synced through ArgoCD, and exposed both environments independently
via AWS Application Load Balancers using the AWS Load Balancer Controller.

## Steps Completed
1. Provisioned EKS cluster (v1.31) + VPC + managed node group via Terraform
2. Configured kubectl and eksctl, verified nodes and namespaces
3. Created `blue` and `green` namespaces
4. Installed ArgoCD in-cluster, accessed via CLI over port-forward
5. Registered Git repo (SSH) with ArgoCD
6. Created ArgoCD Applications `food-delivery-blue` and `food-delivery-green`,
   each pointing at the same Helm chart but deployed into separate namespaces
7. Installed metrics-server (for HPA) and the AWS EBS CSI driver (for MongoDB's
   PersistentVolumeClaim), each requiring their own IAM role via OIDC
8. Installed the AWS Load Balancer Controller via Helm, with its own IAM policy
   and service account
9. Fixed the Ingress to use the `alb` ingress class with proper annotations
10. Verified both environments serve traffic independently through their own ALBs

## Issues Encountered & Fixes

### Issue 1: KMS AccessDenied during cluster creation
**Cause:** IAM user lacked `kms:TagResource`, needed for the EKS module's default
customer-managed KMS key (used to encrypt Kubernetes secrets at rest).
**Fix:** Set `cluster_encryption_config = []` in Terraform to skip the customer-managed
key and rely on EKS's default encryption instead (acceptable for this learning cluster).

### Issue 2: eks:CreateCluster AccessDenied
**Cause:** IAM user had no EKS permissions at all.
**Fix:** Administrator attached broader permissions to the IAM user.

### Issue 3: Terraform state drift caused a cluster replacement plan
**Cause:** An interrupted apply left the cluster resource marked as "tainted" in
Terraform state, even though the cluster was healthy in AWS. The next plan showed
"must be replaced," which would have destroyed and recreated the entire cluster.
**Fix:** `terraform untaint module.eks.aws_eks_cluster.this[0]` before re-applying.
**Lesson:** Always inspect a plan carefully for `+/-` (replace) actions before
approving apply, especially after any interrupted or failed run.

### Issue 4: Node group failed - unsupported AMI for cluster version
**Cause:** An earlier apply auto-corrected the cluster's Kubernetes version back down
from 1.31 (the AWS-managed live version) to 1.30 (the value still in main.tf, stale).
AWS no longer supports the node AMI for 1.30 in this account/region.
**Fix:** Updated `cluster_version = "1.31"` in Terraform to match what was actually
running, before creating the node group.

### Issue 5: kubectl "you must be logged in to the server"
**Cause:** By default, the EKS Terraform module does not grant the cluster-creating
IAM identity any Kubernetes RBAC access - AWS auth and Kubernetes RBAC are separate.
**Fix:** Added `enable_cluster_creator_admin_permissions = true` to the EKS module,
which creates an access entry granting the creator cluster-admin via RBAC.

### Issue 6: Helm chart hardcoded to one namespace
**Cause:** All templates used `namespace: {{ .Values.namespace }}`, pointing every
release at a single hardcoded `food-delivery` namespace regardless of where ArgoCD
was told to deploy it - breaking the blue/green pattern entirely.
**Fix:** Changed every template to `namespace: {{ .Release.Namespace }}`, letting the
same chart deploy cleanly into whichever namespace the ArgoCD Application specifies.

### Issue 7: HPA stuck reporting unknown CPU metrics
**Cause:** EKS does not ship metrics-server by default.
**Fix:** Installed metrics-server from the upstream manifest.

### Issue 8: MongoDB PVC stuck Pending
**Cause:** No EBS CSI driver installed, so no controller existed to actually
provision the EBS volume the PVC was requesting - even though a StorageClass
existed, nothing could fulfill it.
**Fix:** Created an IAM role via `eksctl create iamserviceaccount` (using OIDC trust),
then installed the `aws-ebs-csi-driver` EKS addon using that role. Recreated the
StorageClass with the correct CSI provisioner (`ebs.csi.aws.com`, not the older
in-tree `kubernetes.io/aws-ebs`).

### Issue 9: Ingress never got an ALB address
**Cause:** The Ingress template specified `ingressClassName: ngnix` (a typo, and also
the wrong controller entirely - no nginx ingress controller was ever installed).
**Fix:** Installed the AWS Load Balancer Controller (own IAM policy + service account
via OIDC), then corrected the Ingress to `ingressClassName: alb` with the required
`alb.ingress.kubernetes.io/*` annotations (scheme, target-type, listen-ports).

### Issue 10: Node group stuck draining during scale-down
**Cause:** PodDisruptionBudgets on `coredns` and `ebs-csi-controller` blocked
graceful eviction (`ALLOWED DISRUPTIONS: 0`), stalling the scale-to-zero operation.
**Fix:** For a learning cluster being paused overnight, force-terminated the EC2
instances directly via `aws ec2 terminate-instances` rather than waiting on a
graceful drain that PDBs were blocking indefinitely.

## Architecture











Task 21 — AWS RDS + Terraform + Secrets Manager

This task involved provisioning a production-style AWS RDS database using Terraform, with remote state management via S3 and DynamoDB locking, and credentials sourced securely from AWS Secrets Manager rather than hardcoded values. The workflow followed a deliberate sequence: first setting up the S3/DynamoDB backend, then creating an RDS instance manually through the AWS Console to understand the VPC → Subnet Group → Security Group → RDS relationship firsthand, before reproducing the same setup in Terraform using the account's existing default VPC. Once the Terraform-managed instance was verified working, the manual instance was deleted to avoid running (and paying for) two databases simultaneously. The final and most important step rewired the Terraform configuration to pull database credentials from a Secrets Manager secret via a data source, instead of a plain hardcoded variable, and confirmed this was a safe in-place update rather than a destructive replacement before applying.

Three real issues came up during the build. First, the RDS instance's endpoint resolved to a private IP even though public access was selected during Console creation — PubliclyAccessible had actually been set to false, fixed by explicitly re-enabling it via aws rds modify-db-instance --publicly-accessible --apply-immediately. Second, after switching credentials to come from Secrets Manager, a password mismatch briefly caused access-denied errors — resolved by resetting the master password directly through the AWS CLI and updating the secret to match, rather than guessing at what value was actually set. Third, terraform plan kept showing a password diff on every run even when nothing had actually changed — this turned out to be expected behavior, since RDS master passwords are write-only and Terraform can never read back the live value to confirm it matches config, so applying was safe each time regardless of the repeated diff.

State locking was verified with a real concurrent-access test: holding one terraform apply at its confirmation prompt while running terraform plan from a second terminal produced a genuine ConditionalCheckFailedException from DynamoDB, proving the lock mechanism actively blocks simultaneous state modifications rather than just being configured and untested. Security was handled by restricting the RDS security group to a single /32 CIDR instead of 0.0.0.0/0, keeping all real credentials out of Git via .gitignore (only a placeholder terraform.tfvars.example was committed), and storing Terraform state in an encrypted, versioned, non-public S3 bucket — with the explicit understanding that Secrets Manager alone doesn't make Terraform state itself secure, since resource attributes can still surface in the state file, making remote state encryption and access control a separate, necessary layer of protection.
