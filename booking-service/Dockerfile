FROM golang:1.13.1

WORKDIR /go/src/cinemas-microservices/booking-service/src

COPY src /go/src/cinemas-microservices/booking-service/src

RUN go mod init && \
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM crizstian/cinemas-base-image:alpine-v0.1-tls

WORKDIR /tmp

ENV APP_NAME booking-service

COPY --from=0 /go/src/cinemas-microservices/booking-service/src/main .

CMD ["/tmp/main"]