#!/bin/bash
# Startup script for Project Fleet Lab on GCP VM
set -e

# 1. Install system dependencies
sudo apt-get update
sudo apt-get install -y python3 python3-pip nginx git openssh-server sudo

# 2. Clone the repo (if not already present)
REPO_URL="https://github.com/pratiyk/project-fleet-lab.git"
REPO_DIR="/opt/project-fleet-lab"
if [ ! -d "$REPO_DIR" ]; then
    sudo git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

# 3. Python environment setup
sudo pip3 install -r requirements.txt

# 4. Copy Nginx config
sudo cp nginx/default.conf /etc/nginx/sites-available/default
sudo systemctl restart nginx


# 5. SSH key setup (GCP uses key-based authentication by default)
if id "devops" &>/dev/null; then
    echo "User devops already exists."
else
    sudo useradd -m devops
fi
sudo mkdir -p /home/devops/.ssh
if [ -f ssh/id_rsa.pub ]; then
    sudo cp ssh/id_rsa.pub /home/devops/.ssh/authorized_keys
fi
sudo chown -R devops:devops /home/devops/.ssh
sudo chmod 700 /home/devops/.ssh
sudo chmod 600 /home/devops/.ssh/authorized_keys

# Disable password authentication for SSH (enforce key-based auth)
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# 6. Systemd service setup
sudo cp systemd/fleet-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable fleet-monitor.service
sudo systemctl start fleet-monitor.service

# 7. Export environment variables (edit as needed)
export AWS_ACCESS_KEY_ID=AKIAEXAMPLE
export AWS_SECRET_ACCESS_KEY=SECRETEXAMPLE
export AWS_DEFAULT_REGION=us-east-1

# 8. Start the Flask app (background)
sudo nohup python3 app/app.py > /var/log/projectfleet-app.log 2>&1 &

# 9. Start the mock metadata server (background)
sudo nohup python3 app/mock_metadata.py > /var/log/projectfleet-metadata.log 2>&1 &

echo "Project Fleet Lab setup complete."
