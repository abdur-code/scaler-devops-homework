FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# systemd-sysv gives the container a real init, which is what journalctl needs
RUN apt-get update && \
    apt-get install -y systemd systemd-sysv nginx sudo adduser && \
    rm -rf /var/lib/apt/lists/*

CMD ["/sbin/init"]
