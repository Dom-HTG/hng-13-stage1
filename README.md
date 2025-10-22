# HNG13 DEVOPS STAGE-1 TASK

This project provides a simple **Bash deployment script** that automates the setup and deployment of a Dockerized server written in Golang to **Google Cloud Platform (GCP)**.

It handles:
- Installing required dependencies  
- Deploying your Docker container  
- Configuring NGINX as a reverse proxy  
- Running health checks  
- Logging all operations safely

---

## Author
- Dominic Ifechuku (dominicdutchboy@gmail.com)

---

## Features

-  **Automatic setup** — installs Docker, Docker Compose, and Nginx  
-  **Deploys Dockerized Application** — clones repository code or pull latest changes if already exists 
-  **Nginx Reverse Proxy** — routes traffic to app container  
-  **Health Validation** — checks container, service, and HTTP response status code
-  **Logging & Error Handling** — saves output to `logs/deploy_YYYYMMDD.log` logfile
-  **Safe** — safe rerun without breaking existing setup  

---

## Requirements

- Ubuntu (20.04 or newer)
- A **GCP Compute Engine VM**
- SSH access to the target server
- Git and Docker installed locally
- A **GitHub Personal Access Token** (for private repositories)

---

## Usage

### Clone the Repository
```bash
git clone https://github.com/Dom-HTG/hng13-stage1-devops.git
cd hng13-stage1-devops
```

### Make script Executable
```bash
chmod +x deploy.sh
```

### copy SSH private key into linux-debian base directory
```bash
cp /mnt/c/Users/HP/Documents/host.pem ~/.ssh/host.pem
~/.ssh/host.pem
chmod 600 ~/.ssh/host.pem
```

### Deploy to GCP VM
```bash
./deploy.sh
```

### Verify Deployment
```bash
curl -I http://34.60.35.217
```

### Cleanup
```bash
./deploy.sh --cleanup
```
### Dry-Run
```bash
./deploy.sh --dry-run
```
