FROM nginx:alpine

COPY startup /tmp/
COPY files/bin /tmp/
COPY files/template /tmp/
COPY files/certs/*.* /etc/nginx/conf.d/certs/

COPY files/ca.crt.pem /tmp/
COPY files/ct.hcl /tmp/
COPY files/ct-config.hcl /tmp/
COPY files/envconsul.hcl.tmpl /tmp/

RUN apk update && apk --no-cache add linux-headers curl unzip openssl ca-certificates wget libgcc nfs-utils jq tar libstdc++ bash

RUN chmod -R +x /tmp && /tmp/installhashi.sh

# Enabler for "Forward Secrecy & Diffie Hellman Ephemeral Parameters"
RUN mkdir -p /usr/local/nginx/ssl && \
  openssl dhparam -out /usr/local/nginx/ssl/dhparam.pem 2048

ENV PATH /usr/local/bin:$PATH
ENV PATH /usr/local/nginx/sbin:$PATH

#Container ENV's
ENV CONSUL_SCHEME http
ENV CONSUL_PORT 8500
ENV CONSUL_HTTP_SSL false
ENV CA_CERT_FILE /tmp/ca.crt.pem
ENV VAULT_ADDR https://vault.service.consul:8200
ENV ENABLE_SECRETS false
ENV CONSUL_HTTP_TOKEN ""

ENV IS_ENTRY_POINT true
ENV ACTIVE_ACTIVE true
# ENV APP_NAME "nginx-web-service"
ENV SERVICE_PORT 80
ENV START_CMD /tmp/startProcess.sh
ENV CERT_PATH /etc/nginx/conf.d/certs/localhost.crt
ENV KEY_PATH /etc/nginx/conf.d/certs/localhost.key

WORKDIR /etc/nginx/
ENTRYPOINT [ "bash", "/tmp/pre-start.sh" ]