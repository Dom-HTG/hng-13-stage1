# HNG13 DEVOPS STAGE-1 TASK

This repository contains a minimal Golang web server and a Bash deployment script (deploy.sh) that automates deployment to GCP VM instance.

---

## Quick start

1. Make the script executable:
```bash
chmod +x deploy.sh
```

2. Copy private key path on local machine to SSH base directory:
```bash
cp /path/to/private_key ~/.ssh/host.pem
chmod 600 ~/.ssh/host.pem
```

3. Run the deploy script and follow prompts:
```bash
./deploy.sh
```

- For a dry-run [Set DRY_RUN=true]:
```bash
./deploy.sh --dry-run
```
- To cleanup [Set CLEANUP=true]:
```bash
./deploy.sh --cleanup
```

---

## Requirements

- Git, SSH, scp
- Remote VM: Ubuntu (20.15)
- Remote user with sudo privileges
- SSH access from your machine to the VM
- Docker

---

## Deployment Script (deploy.sh)

- Configurations
  - PORT_DEFAULT=8080 — default container application port.
  - DRY_RUN — when true the script will only log remote commands instead of executing them.
  - CLEANUP — when true the script performs a remote cleanup and exits.
  - LOGFILE — all actions are appended to a timestamped logfile created locally.

- Parameter collection (collect_params)
  - Prompts for SSH username, SSH host/IP, SSH key path, Git repository URL, branch and internal app port.

- Remote execution wrapper (run_remote_cmd)
  - All remote commands are executed through ssh -i "$SSH_KEY" ... unless DRY_RUN is enabled, in which case they are logged.

- SSH check (check_ssh)
  - Tries a simple ssh command to verify connectivity before making changes.

- Remote preparation (prepare_remote)
  - Installs docker.io, docker-compose, nginx via apt and enables services.
  - Adds the deploy user to the docker group (usermod -aG docker).

- Deployment (deploy_app)
  - Locally clones or updates the repo into ./${REPO_DIR}.
  - Copies project files to the remote /tmp via scp
  - On the remote host:
    - If docker-compose.yml is present, runs `docker compose up -d --build`.
    - Otherwise builds the image with `docker build` and runs the container with `docker run -d --name ... -p hostPort:containerPort`.

- Nginx configuration (configure_nginx)
  - Reloads Nginx after validating configuration.

- Validation (validate)
  - Checks docker service status, container existence, and attempts HTTP Request

- Cleanup (cleanup)
  - Removes the container, the deployment directory, and Nginx site files, then reloads Nginx.

---

## Logfile configuration

- Local logfile: deploy_YYYYMMDD_HHMMSS.log (created in the directory you run the script from).
