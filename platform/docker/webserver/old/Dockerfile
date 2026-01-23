FROM nginx:alpine

ENV PATH /usr/local/bin:$PATH
ENV PATH /usr/local/nginx/sbin:$PATH
ENV HEALTH_CHECK_URL 'http://localhost'

ENV ENABLE_CONTAINER_PILOT true
ENV IS_ENTRY_POINT true
ENV ACTIVE_ACTIVE true
ENV INCLUDE_INDEX_HTML true

#Container ENV's
ENV APP_NAME "nginx-web-service"
ENV SERVICE_PORT 80
ENV CUSTOM_CMD /var/tmp/startCT.sh
ENV CERT_PATH /etc/nginx/conf.d/certs/localhost.crt
ENV KEY_PATH /etc/nginx/conf.d/certs/localhost.key

RUN mkdir -p /var/tmp

COPY common /var/tmp/
COPY common/app.json5 /opt/containerpilot/app.json5
COPY common/certs/*.* /etc/nginx/conf.d/certs/

# nginx config files
COPY nginx/conf/*.conf /etc/nginx/conf.d/
COPY nginx/*.hcl /var/tmp/

# COPY webserver/html/*.* /etc/nginx/html/
COPY webserver/config/*.conf /etc/nginx/conf.d/
COPY webserver/template/*.ctmpl /var/tmp/
COPY webserver/script/*.sh /var/tmp/startup/
COPY webserver/script/*.sh /var/tmp/

RUN chmod -R +x /var/tmp
RUN chmod +x /usr/local/bin/*
RUN chmod +x /var/tmp/*.sh
RUN chmod +x /var/tmp/startup/*.sh

RUN apk update && apk --no-cache add linux-headers curl openssl ca-certificates wget libgcc nfs-utils jq tar libstdc++ bash
RUN /var/tmp/tools/installcontainerpilot.sh
RUN /var/tmp/hashi/installhashi.sh
# Enabler for "Forward Secrecy & Diffie Hellman Ephemeral Parameters"
RUN mkdir -p /usr/local/nginx/ssl && \
  openssl dhparam -out /usr/local/nginx/ssl/dhparam.pem 2048

RUN ls /etc/nginx/conf.d/


EXPOSE 80 443
VOLUME ["/var/log/nginx"]
WORKDIR /etc/nginx/
ENTRYPOINT [ "/var/tmp/startup/startWithConfig.sh" ]