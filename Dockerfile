FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3 python3-pip nginx git openssh-server sudo systemctl && \
    pip3 install flask requests

COPY ./app /app
COPY ./nginx/default.conf /etc/nginx/sites-available/default
COPY ./static /static
COPY ./s3-bucket /s3-bucket
COPY ./ssh /ssh
COPY ./systemd /etc/systemd/system

RUN useradd -m devops && \
    echo 'devops:devops' | chpasswd && \
    mkdir -p /home/devops/.ssh && \
    cp /ssh/id_rsa.pub /home/devops/.ssh/authorized_keys && \
    chown -R devops:devops /home/devops/.ssh && \
    chmod 700 /home/devops/.ssh && \
    chmod 600 /home/devops/.ssh/authorized_keys

RUN echo 'devops ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart fleet-monitor.service' >> /etc/sudoers

EXPOSE 80 22 5000

CMD service ssh start && service nginx start && python3 /app/app.py
