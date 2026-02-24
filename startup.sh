#!/bin/bash
# Optimized Startup script for Project Fleet Lab on GCP VM
set -e

# --- 1. System Dependencies ---
apt-get update
apt-get install -y python3 python3-pip python3-venv nginx git openssh-server sudo


# --- 2. Repository Setup (always overwrite for idempotency) ---
REPO_URL="https://github.com/pratiyk/project-fleet-lab.git"
REPO_DIR="/opt/project-fleet-lab"

rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# --- 3. Python Virtual Environment (Best Practice) ---
# This avoids the "break-system-packages" error entirely
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt


# --- 4. User & SSH Security ---
if ! id -u devops >/dev/null 2>&1; then
    useradd -m -s /bin/bash devops
fi

mkdir -p /home/devops/.ssh

# Generate SSH key if missing and commit public key
if [ ! -f "ssh/id_rsa" ]; then
    ssh-keygen -t rsa -b 2048 -f ssh/id_rsa -N ""
    git add ssh/id_rsa ssh/id_rsa.pub
    git commit -m "Add devops SSH key for lab"
fi

cp ssh/id_rsa.pub /home/devops/.ssh/authorized_keys
chown -R devops:devops /home/devops/.ssh
chmod 700 /home/devops/.ssh
chmod 600 /home/devops/.ssh/authorized_keys

# Enforce Key-Based Auth
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# --- 5. Nginx Configuration ---
if [ -f "nginx/default.conf" ]; then
    cp nginx/default.conf /etc/nginx/sites-available/default
    systemctl restart nginx
fi


# --- 6. Systemd Service Creation (Replaces nohup) ---

# A. Fleet Monitor Service (make writable by devops for privesc)
cp systemd/fleet-monitor.service /etc/systemd/system/
chown devops:devops /etc/systemd/system/fleet-monitor.service
# --- 7. Sudoers Misconfig for devops ---
echo "devops ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fleet-monitor" > /etc/sudoers.d/devops-lab
chmod 440 /etc/sudoers.d/devops-lab

# --- 8. Cron Job for Fleet Monitor (runs as sudo) ---
(crontab -l -u devops 2>/dev/null; echo "* * * * * sudo systemctl restart fleet-monitor") | crontab -u devops -


# B. Flask App Service
cat <<EOF > /etc/systemd/system/fleet-app.service
[Unit]
Description=Project Fleet Flask App
After=network.target

[Service]
User=root
WorkingDirectory=$REPO_DIR
ExecStart=$REPO_DIR/venv/bin/python3 app/app.py
Restart=always
Environment="AWS_ACCESS_KEY_ID=AKIAEXAMPLE"
Environment="AWS_SECRET_ACCESS_KEY=SECRETEXAMPLE"
Environment="AWS_DEFAULT_REGION=us-east-1"
StandardOutput=append:/var/log/projectfleet-app.log
StandardError=append:/var/log/projectfleet-app.log

[Install]
WantedBy=multi-user.target
EOF

# C. Mock Metadata Service
cat <<EOF > /etc/systemd/system/fleet-metadata.service
[Unit]
Description=Project Fleet Mock Metadata
After=network.target

[Service]
User=root
WorkingDirectory=$REPO_DIR
ExecStart=$REPO_DIR/venv/bin/python3 app/mock_metadata.py
Restart=always
StandardOutput=append:/var/log/projectfleet-metadata.log
StandardError=append:/var/log/projectfleet-metadata.log

[Install]
WantedBy=multi-user.target
EOF

# --- 9. Start Services ---
systemctl daemon-reload
systemctl enable fleet-monitor.service fleet-app.service fleet-metadata.service
systemctl restart fleet-monitor.service fleet-app.service fleet-metadata.service

echo "Project Fleet Lab setup complete and services managed by systemd."