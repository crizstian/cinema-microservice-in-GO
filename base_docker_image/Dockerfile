FROM alpine:latest
RUN apk --no-cache add ca-certificates curl unzip jq

COPY ct.hcl /tmp/ct.hcl
COPY envconsul.hcl.tmpl /tmp/envconsul.hcl.tmpl
COPY *.sh /tmp/
COPY ca.crt.pem /tmp/

RUN chmod +x /tmp/*.sh && sh /tmp/install-tools.sh

ENV CONSUL_SCHEME http
ENV CONSUL_PORT 8500
ENV CONSUL_HTTP_SSL false
ENV CA_CERT_FILE /tmp/ca.crt.pem

ENTRYPOINT [ "/tmp/pre-start.sh" ]