FROM debian:jessie-backports
MAINTAINER rt.pi@readytalk.com

# Wait until apt-get is ready
RUN /bin/bash -c "while apt-get update | tee >(cat 1>&2) | grep ^[WE]:; do echo apt-get update failed, retrying; sleep 1; done;"

# Go get consul binary
ENV CONSUL_VERSION 0.6.3
ENV CONSUL_SHA256 b0532c61fec4a4f6d130c893fd8954ec007a6ad93effbe283a39224ed237e250
ADD https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip /consul.zip

# Install everything we need
RUN apt-get install -y --no-install-recommends \
  curl wget unzip python python-pip vim cron \
     && apt-get clean
RUN pip install boto awscli

# Setup consul
RUN mkdir /consul \
    && mkdir -p /tmp/consul \
    && mv /consul.zip /consul/. \
    && cd /consul \
    && unzip consul.zip \
    && useradd -m consul

# Expose ports 
EXPOSE 8300 8301 8301/udp 8302 8302/udp 8400 8500 8600 8600/udp
ENV DNS_RESOLVES consul
ENV DNS_PORT 8600

# Add scripts to look for other consul-servers
ADD boot-scripts/ /scripts
WORKDIR /scripts
RUN chmod +x setup_consul.sh
RUN chmod +x remove_failed.sh

CMD ./setup_consul.sh server && \
    ./remove_failed.sh && \
    /consul/consul agent -config-dir /root/consul/consul.json
