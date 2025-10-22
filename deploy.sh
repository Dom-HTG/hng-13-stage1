#!/bin/bash
set -euo pipefail

# config
PORT_DEFAULT=8080
DRY_RUN=false
CLEANUP=false
LOGFILE="deploy_$(date +%Y%m%d_%H%M%S).log"

# logging
log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOGFILE"; }
fail() { log "[ERROR] $*"; exit 1; }

# remote command execution with dry-run support
run_remote_cmd() {
  local cmd="$*"
  if [ "$DRY_RUN" = true ]; then
    log "[DRY-RUN] ssh $SSH_USER@$SSH_HOST: $cmd"
  else
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" "$cmd"
  fi
}

# parameter collection
collect_params() {
  read -rp "SSH username: " SSH_USER
  read -rp "SSH host/IP: " SSH_HOST
  read -rp "Path to SSH key [~/.ssh/id_rsa]: " SSH_KEY
  SSH_KEY=${SSH_KEY:-~/.ssh/id_rsa}
  read -rp "Git repository URL: " REPO_URL
  read -rp "Git branch [main]: " GIT_BRANCH
  GIT_BRANCH=${GIT_BRANCH:-main}
  read -rp "App port inside container [${PORT_DEFAULT}]: " SERVER_PORT
  SERVER_PORT=${SERVER_PORT:-$PORT_DEFAULT}

  REPO_DIR=$(basename -s .git "$REPO_URL")
  REMOTE_PATH="/home/${SSH_USER}/deployments/${REPO_DIR}"
}

# SSH connection test
check_ssh() {
  log "Testing SSH connection..."
  if [ "$DRY_RUN" = true ]; then
    log "[DRY-RUN] Would test SSH connectivity"
    return 0
  fi
  ssh -i "$SSH_KEY" -o ConnectTimeout=6 "$SSH_USER@$SSH_HOST" "echo connected" >/dev/null || fail "SSH connection failed"
  log "SSH connection OK."
}

# remote server preparation
prepare_remote() {
  log "Preparing remote server..."
  run_remote_cmd "sudo apt-get update -y && sudo apt-get install -y docker.io docker-compose nginx && sudo apt install -y rsync"
  run_remote_cmd "sudo systemctl enable --now docker nginx"
  run_remote_cmd "sudo usermod -aG docker $SSH_USER || true"
  run_remote_cmd "docker --version && docker compose version && nginx -v"
  log "Remote server ready."
}

# application deployment
deploy_app() {
  log "Deploying app..."

  if [ "$DRY_RUN" = false ]; then
    log "Copying files to remote server..."

    cp -r "./${REPO_DIR}" "/tmp/${REPO_DIR}_temp"
    rm -rf "/tmp/${REPO_DIR}_temp/.git"

    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r "./${REPO_DIR}" "$SSH_USER@$SSH_HOST:/tmp/"
    rm -rf "/tmp/${REPO_DIR}_temp"
  else
    log "[DRY-RUN] Would copy project with scp"
  fi

  run_remote_cmd "
    sudo mkdir -p ${REMOTE_PATH} && sudo rm -rf ${REMOTE_PATH}/* && sudo cp -r /tmp/${REPO_DIR}/* ${REMOTE_PATH}/
  "

  run_remote_cmd "
    cd ${REMOTE_PATH} && \
    if [ -f docker-compose.yml ]; then
      sudo docker compose down --remove-orphans || true;
      sudo docker compose up -d --build;
    else
      sudo docker build -t ${REPO_DIR}:latest . && \
      sudo docker rm -f ${REPO_DIR} || true && \
      sudo docker run -d --name ${REPO_DIR} -p ${SERVER_PORT}:${SERVER_PORT} ${REPO_DIR}:latest;
    fi
  "

  log "App deployed."
}

# NGINX configuration
configure_nginx() {
  log "Configuring Nginx..."
  local conf="/etc/nginx/sites-available/${REPO_DIR}.conf"
  run_remote_cmd "echo '
server {
  listen 80;
  server_name ${SSH_HOST};
  location / {
    proxy_pass http://127.0.0.1:${SERVER_PORT};
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}' | sudo tee ${conf} > /dev/null"

  run_remote_cmd "sudo ln -sf ${conf} /etc/nginx/sites-enabled/${REPO_DIR}.conf"
  run_remote_cmd "sudo nginx -t && sudo systemctl reload nginx"
  log "Nginx configured."
}

# deployment validation
validate() {
  log "Validating deployment..."
  run_remote_cmd "sudo systemctl is-active docker && echo 'Docker OK'"
  run_remote_cmd "sudo docker ps --filter 'name=${REPO_DIR}' --format '{{.Names}}' | grep -q ${REPO_DIR} && echo 'Container running'"
  run_remote_cmd "curl -I http://127.0.0.1:${SERVER_PORT} >/dev/null && echo 'Local HTTP OK'" || log "Local HTTP failed"
  run_remote_cmd "curl -I http://${SSH_HOST} >/dev/null && echo 'Public HTTP OK'" || log "Public HTTP failed"
  log "Validation complete."
}

# cleanup
cleanup() {
  log "Cleaning up old deployment..."
  run_remote_cmd "sudo docker rm -f ${REPO_DIR} || true"
  run_remote_cmd "sudo rm -rf ${REMOTE_PATH}"
  run_remote_cmd "sudo rm -f /etc/nginx/sites-enabled/${REPO_DIR}.conf /etc/nginx/sites-available/${REPO_DIR}.conf"
  run_remote_cmd "sudo systemctl reload nginx"
  log "Cleanup done."
}

# entry point
main() {
  collect_params
  check_ssh

  if [ "$CLEANUP" = true ]; then
    cleanup
    exit 0
  fi

  # Clone repo
  if [ ! -d "./${REPO_DIR}" ]; then
    log "Cloning repository..."
    git clone -b "$GIT_BRANCH" "$REPO_URL" "./${REPO_DIR}" || fail "Failed to clone repo"
  else
    log "Repository already exists, pulling latest changes..."
    (
        cd "./${REPO_DIR}" || fail "Failed to enter repo directory"
        git fetch origin "$GIT_BRANCH"
        git reset --hard "origin/$GIT_BRANCH"
    ) || fail "Failed to update repository"
    log "Pull complete!"
  fi


  prepare_remote
  deploy_app
  configure_nginx
  validate

  log "Deployment complete!"
}

main "$@"
