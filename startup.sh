#!/bin/bash
# Optimized Startup script for Project Fleet Lab on GCP VM
# Designed for Vulnerability Simulation (Privilege Escalation)
set -e

# --- 1. System Dependencies ---
apt-get update
apt-get install -y python3 python3-pip python3-venv nginx git openssh-server sudo cron

# --- 2. Repository Setup ---
# Always wipe and clone fresh to ensure code updates from GitHub are applied on reset
REPO_URL="https://github.com/pratiyk/project-fleet-lab.git"
REPO_DIR="/opt/project-fleet-lab"

rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# --- 3. Python Virtual Environment ---
# Handles PEP 668 and keeps the OS Python environment clean
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# --- 4. User & SSH Security ---
if ! id -u devops >/dev/null 2>&1; then
    useradd -m -s /bin/bash devops
fi

# Set up SSH directory
mkdir -p /home/devops/.ssh

# Generate keys if they don't exist in the repo
if [ ! -f "ssh/id_rsa" ]; then
    mkdir -p ssh
    ssh-keygen -t rsa -b 2048 -f ssh/id_rsa -N ""
fi

# Deploy keys to the devops user
cp ssh/id_rsa.pub /home/devops/.ssh/authorized_keys
cp ssh/id_rsa /home/devops/id_rsa
chown -R devops:devops /home/devops/
chmod 700 /home/devops/.ssh
chmod 600 /home/devops/.ssh/authorized_keys
chmod 600 /home/devops/id_rsa

# Enforce Key-Based Auth
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# --- 5. Nginx Configuration ---
if [ -f "nginx/default.conf" ]; then
    cp nginx/default.conf /etc/nginx/sites-available/default
    systemctl restart nginx
fi

# --- 6. Systemd Service Creation ---

# A. Fleet Monitor Service (The VULNERABLE Service)
# LAB CONFIG: We make the service file WRITABLE by the devops user
cp systemd/fleet-monitor.service /etc/systemd/system/
chown devops:devops /etc/systemd/system/fleet-monitor.service

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

# --- 7. Sudoers Misconfig (PrivEsc Path #1) ---
# LAB CONFIG: Allows devops to restart the monitor service as root without a password
echo "devops ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fleet-monitor" > /etc/sudoers.d/devops-lab
chmod 440 /etc/sudoers.d/devops-lab

# --- 8. Cron Job for Fleet Monitor (Exploit Automation) ---
# LAB CONFIG: Restarts the service every minute to trigger the student's payload
echo "* * * * * root systemctl restart fleet-monitor" > /etc/cron.d/fleet-lab-cron
chmod 644 /etc/cron.d/fleet-lab-cron

# --- 9. Start Services ---
systemctl daemon-reload
systemctl enable fleet-monitor.service fleet-app.service fleet-metadata.service
systemctl restart fleet-monitor.service fleet-app.service fleet-metadata.service

echo "Project Fleet Lab setup complete. Happy Hunting!"