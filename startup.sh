#!/bin/bash
# Optimized Startup script for Project Fleet Lab on GCP VM
# Designed for Vulnerability Simulation (Privilege Escalation)
set -e

# --- 1. System Dependencies ---
apt-get update
apt-get install -y python3 python3-pip python3-venv nginx git openssh-server sudo cron

# --- 2. Repository Setup ---
REPO_URL="https://github.com/pratiyk/project-fleet-lab.git"
REPO_DIR="/opt/project-fleet-lab"

rm -rf "$REPO_DIR"
git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"

# LAB CONFIG: Create a "leaked" Git history in static/docs/
# This mimics a developer accidentally committing secrets
DOCS_DIR="$REPO_DIR/static/docs"
mkdir -p "$DOCS_DIR"
cd "$DOCS_DIR"
git init
git config user.email "lead-engineer@projectfleet.io"
git config user.name "Lead Engineer"

# Initial commit with secrets
cat <<EOF > aws_config.txt
[default]
aws_access_key_id = AKIA5UBCLEAKED123
aws_secret_access_key = v9sX7LpQn8B2mZ3yR5aK1w9T4vE6xN0uC2jY8hM0
EOF
git add aws_config.txt
git commit -m "Add AWS config for testing"

# Second commit removing secrets (but they stay in history)
rm aws_config.txt
git add .
git commit -m "Remove sensitive config before deployment"

# Ensure the .git directory is accessible via web
chmod -R 755 "$DOCS_DIR/.git"

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

# LAB CONFIG: Copy SSH private key to "S3 bucket" for the student to find
mkdir -p s3-bucket
cp ssh/id_rsa s3-bucket/id_rsa_devops
chmod 644 s3-bucket/id_rsa_devops

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
# Path fixed to /opt/project-fleet-lab
sed -i "s|/app/fleet_monitor.py|$REPO_DIR/app/fleet_monitor.py|g" systemd/fleet-monitor.service
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
# LAB CONFIG: These are the "temp" credentials returned by the metadata service
# They should match what the student expects to use for "S3" access
Environment="AWS_ACCESS_KEY_ID=AKIA5UBC_TEMP_789"
Environment="AWS_SECRET_ACCESS_KEY=t3mp_s3cr3t_vlu3_xyz123"
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

# D. Mock S3 Service
cat <<EOF > /etc/systemd/system/fleet-s3.service
[Unit]
Description=Project Fleet Mock S3
After=network.target

[Service]
User=root
WorkingDirectory=$REPO_DIR
ExecStart=$REPO_DIR/venv/bin/python3 app/mock_s3.py
Restart=always
StandardOutput=append:/var/log/projectfleet-s3.log
StandardError=append:/var/log/projectfleet-s3.log

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
systemctl enable fleet-monitor.service fleet-app.service fleet-metadata.service fleet-s3.service
systemctl restart fleet-monitor.service fleet-app.service fleet-metadata.service fleet-s3.service

echo "Project Fleet Lab setup complete. Happy Hunting!"