# 🚀 CI/CD Pipeline with Jenkins, Docker & Kubernetes on AWS EKS

This project demonstrates a **production-ready CI/CD pipeline** that builds a Java application, packages it into a Docker image, pushes it to Docker Hub, and deploys it to **AWS EKS** using **Jenkins** and **Kubernetes rolling updates**.

It also includes a **one-shot automation script** to set up all required tools and provision an EKS cluster on Ubuntu.

---

## 📌 Architecture Overview

Developer Commit
      |
   Jenkins
      |
      |-- Maven Build (JAR)
      |-- Docker Build & Push
      |-- kubectl Apply with Rollbacks
      |-- Rolling Update
 AWS EKS (Kubernetes)
      |
 LoadBalancer Service → Application

 
---

## 🧰 Tech Stack

- Java 21
- Maven
- Docker
- Jenkins
- Kubernetes
- AWS EKS
- eksctl
- AWS CLI

---

## ⚙️ Prerequisites

- Ubuntu (20.04+ recommended)
- AWS account
- IAM user with EKS permissions
- Docker Hub account
- Jenkins credentials configured:
- Docker Hub credentials ID: `dockerhub-credentials`

---

## 🛠️ Automated Setup Script

### 📄 aws-project.sh

This script installs and configures:

- OpenJDK 21
- Jenkins
- Maven
- Docker Engine
- kubectl
- AWS CLI
- eksctl
- zip / unzip
- Creates an EKS cluster
- Configures kubectl for both user and Jenkins
- Enables Jenkins & Docker services
- Adds Jenkins to Docker group
- Creates Kubernetes namespace `demo`

### ▶️ Usage

```bash
chmod +x aws-project.sh

./aws-project.sh <cluster> <region> <nodegroup> <nodes> <min> <max> <instance-type>

```

### 📝 Example 

```bash
./aws-project.sh demo-cluster ap-south-1 demo-ng 2 1 3 t3.medium

```

### ⚠️ Ensure AWS CLI is configured before running the script:

```bash
aws configure

```
---

## 🔄 Jenkins CI/CD Pipeline

### 📄 Jenkinsfile

The Jenkins pipeline performs the following stages:

### 1️⃣ Build JAR

- Executes Maven build:

```bash
mvn clean package -DskipTests

```

- Archives the generated JAR file

### 2️⃣ Docker Image Build

- Builds Docker image using Jenkins build number:

`app:v-${BUILD_NUMBER}`

### 3️⃣ Docker Image Push

- Logs in to Docker Hub using Jenkins credentials

- Tags the image:

  `manashbarman007/app:v-${BUILD_NUMBER}`


- Pushes the image to Docker Hub

- Logs out after push

### 4️⃣ Deploy to Kubernetes

- Applies Kubernetes manifests from the k8s/ directory

- Updates the Deployment image dynamically

- Waits for rollout completion

- Automatically rolls back on deployment failure

### 5️⃣ Cleanup

- Cleans unused Docker images and containers:

```bash
docker system prune -f

```

---

## ☸️ Kubernetes Configuration

### 🔹 Deployment

- Name: myapp

- Namespace: demo

- Replicas: 4

- Strategy: RollingUpdate

  `maxSurge: 25%`

  `maxUnavailable: 25%`

  `Container Port: 8081`

- Image updated dynamically by Jenkins

- Readiness Probe:

  `/actuator/health/readiness`


- Resource Requests:

  `CPU: 100m`

  `Memory: 100Mi`

- Resource Limits:

  `CPU: 500m`

  `Memory: 256Mi`

### 🔹 Service

- Name: myapp-svc

- Namespace: demo

- Type: LoadBalancer

- Exposes application on port `80`

- Routes traffic to container port `8081`

### 🚀 How to Deploy

- Run the setup script to install tools and create the EKS cluster

- Access Jenkins:

  `http://<server-ip>:8080`


- Create a Jenkins Pipeline job

- Configure SCM to point to this repository

- Trigger the pipeline

- Jenkins will:

   `Build the Java application`

   `Build and push Docker image`
  
   `Deploy application to EKS`

   `Perform zero-downtime rolling updates`

### 🔁 Rollback Strategy

- If deployment fails, Jenkins automatically executes:

``` bash
kubectl rollout undo deployment/myapp -n demo

```

This ensures fast recovery to the previous stable version.

### 🧯 Troubleshooting

- Docker permission denied

- Not logged out and logged in the machine after user was added to the docker group or run the below command as alternatice : 
  ``` bash
   newgrp docker
  ```

- kubectl not working in Jenkins

- Ensure AWS credentials are configured for the jenkins user

- Verify kubeconfig exists for Jenkins user

- Pods stuck in Pending or NotReady

``` bash
 kubectl describe pod <pod-name> -n demo

```

### ✨ Key Highlights

- End-to-end CI/CD automation

- Infrastructure provisioning + application deployment

- Jenkins-driven Docker image versioning

- Kubernetes rolling updates with readiness probes

- Automated rollback on failure

- Production-grade DevOps workflow

---

## 👨‍💻 Author
**Manash Barman**  
Backend Developer | Java, Spring Boot, Microservices  
[LinkedIn](https://www.linkedin.com/in/manash-barman-15b1833a1/) | [GitHub](https://github.com/manashbarman007-cmyk)

---



