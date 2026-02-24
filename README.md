# ProjectFleet Vulnerable Lab

This is a purposely vulnerable DevOps lab simulating a real-world CI/CD dashboard with common misconfigurations and secrets exposure.

## Scenario
A startup's DevOps team builds "ProjectFleet" to track CI/CD pipelines. In a late-night push, the lead engineer clones their AWS creds into `/app/static/docs/` for "quick testing," commits to a Git repo served publicly, and deploys without review. Exposed metadata leads to instance role abuse, and a cron job runs as sudo due to hasty scripting.

## Attack Chain
1. **Recon:** Nmap reveals ports 80 (Nginx), 22 (SSH). Gobuster finds `/static/docs/` with a `.git` directory.
2. **Initial Foothold:** Download Git objects via git-dumper; extract AWS access key from commit history. Key has IAM role for EC2 metadata read.
3. **Privilege Ramp:** Use creds for SSRF to `169.254.169.254/latest/meta-data/iam/security-credentials/`; steal temp creds with S3 read/write on sensitive buckets.
4. **User Shell:** Temp creds access S3 bucket with uploaded SSH private key; SSH as devops user.
5. **Root Privesc:** devops can sudo `/usr/bin/systemctl restart fleet-monitor` without password (misconfig for "easy restarts"). Exploit via custom service file edit for reverse shell.

## Services
- Flask app (dashboard, SSRF endpoint)
- Mock EC2 metadata server (port 8000)
- Mock S3 server (port 9000)
- Nginx reverse proxy (port 80)
- SSH (port 22)

## Usage
- Deploy or reset the VM. The `startup.sh` script will auto-provision everything.
- Visit the web dashboard at `http://<vm-ip>/`.
- Begin enumeration and exploitation as described above.

**For educational use only!**
# ProjectFleet Vulnerable Lab
## Automated GCP VM Setup

To automate the setup of this lab on a GCP VM:

1. **Create a VM** (Ubuntu 22.04 recommended).
2. **Attach the startup script**:
	- Upload or reference `startup.sh` as your VM startup script.
	- Make it executable:
	  ```bash
	  chmod +x startup.sh
	  ```
3. **Startup script actions:**
	- Installs system and Python dependencies
	- Clones this repo to `/opt/project-fleet-lab`
	- Sets up Nginx, SSH, and systemd service
	- Exports AWS environment variables
	- Starts the Flask app and mock metadata server
4. **Custom Image**: Once setup is complete and verified, create a custom image from the VM for future use.

### Requirements
- Python 3, pip
- Nginx
- Git
- Systemd (default on Ubuntu)

### Environment Variables
Edit the `startup.sh` script to set your own AWS credentials if needed.

---

# ProjectFleet Vulnerable Lab

## Overview
This lab simulates a DevOps team's internal project management app with real-world vulnerabilities for hands-on exploitation.

### Attack Chain
1. **Recon**: Nginx serves Flask app and exposes `/static/docs/.git`.
2. **Git Leak**: AWS credentials are leaked in Git commit history.
3. **SSRF**: App allows SSRF to cloud metadata endpoint (mocked at :8000).
4. **S3 Access**: Stolen creds allow S3 bucket access (simulated locally).
5. **SSH**: S3 bucket contains SSH private key for `devops` user.
6. **Root Privesc**: `devops` can sudo `systemctl restart fleet-monitor` due to misconfigured sudoers.

## Setup
- Dockerized (Ubuntu 22.04 base)
- Flask app in `/app`
- Nginx config in `/nginx`
- Static docs in `/static/docs` (with .git)
- S3 bucket simulated in `/s3-bucket`
- SSH keys in `/ssh`
- systemd service in `/systemd`

## Exploitation Steps
1. Enumerate `/static/docs/.git` and extract AWS creds from commit history.
2. Use SSRF in `/ssrf` to access `http://localhost:8000/latest/meta-data/iam/security-credentials/`.
3. Use creds to access `/s3-bucket` (simulated S3).
4. Retrieve SSH key, login as `devops` via SSH.
5. Exploit sudo misconfig to get root via `systemctl restart fleet-monitor`.

---

For detailed walkthrough, see comments in each file and the exploitation steps above.
