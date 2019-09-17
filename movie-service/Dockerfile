FROM golang:1.10

# Install go dependencies
RUN go get -u github.com/labstack/echo && go get github.com/dgrijalva/jwt-go

WORKDIR /go/src/cinemas-microservices/movie-service/src

COPY src /go/src/cinemas-microservices/movie-service/src

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl

WORKDIR /

COPY --from=0 /go/src/cinemas-microservices/movie-service/src/main .

CMD ["./main"]