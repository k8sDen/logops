FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y nginx rsyslog rsyslog-kafka ca-certificates curl gnupg systemd netcat&& \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY rsyslog.conf /etc/rsyslog.conf

COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/spool/rsyslog
RUN chown syslog:adm /var/spool/rsyslog
RUN chmod 755 /var/spool/rsyslog
RUN mkdir -p /var/log/nginx

EXPOSE 80 514

CMD service rsyslog start && nginx -g 'daemon off;'
