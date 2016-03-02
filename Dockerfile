FROM debian:jessie-backports
MAINTAINER rt.pi@readytalk.com

RUN /bin/bash -c "while apt-get update | tee >(cat 1>&2) | grep ^[WE]:; do echo apt-get update failed, retrying; sleep 1; done;"

# Install everything we need
RUN apt-get install -y --no-install-recommends \
  curl wget unzip python python-pip vim cron \
     && apt-get clean

RUN pip install boto awscli

ADD consul_*.zip /consul.zip

RUN mkdir /consul \
    && mkdir -p /tmp/consul \
    && mv /consul.zip /consul/. \
    && cd /consul \
    && unzip consul.zip \
    && useradd -m consul

EXPOSE 8300 8301 8301/udp 8302 8302/udp 8400 8500 8600 8600/udp
ENV DNS_RESOLVES consul
ENV DNS_PORT 8600

ADD boot-scripts/ /scripts
WORKDIR /scripts

CMD ["/bin/bash ./setup_consul.sh", " && ", "/bin/bash ./remove_failed.sh", " && ", "/consul/consul", "agent", "-config-dir", "/etc/consul.json"]
