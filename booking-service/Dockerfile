FROM golang:1.10

RUN git clone https://github.com/labstack/echo.git

# Install go dependencies
RUN go get -u github.com/labstack/echo && \
    go get github.com/dgrijalva/jwt-go && \
    go get github.com/sirupsen/logrus && \
    go get gopkg.in/mgo.v2 && \
    go get github.com/stripe/stripe-go

WORKDIR /go/src/cinemas-microservices/booking-service/src

COPY src /go/src/cinemas-microservices/booking-service/src

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl

WORKDIR /

COPY --from=0 /go/src/cinemas-microservices/booking-service/src/main .

CMD ["./main"]