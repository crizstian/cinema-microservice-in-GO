#!/usr/bin/env bash

docker rm -f booking-service-go:v0.3-tls

docker rmi booking-service-go:v0.3-tls

docker image prune

docker volume prune

docker build -t booking-service-go:v0.3-tls .

docker tag booking-service-go:v0.3-tls crizstian/booking-service-go:v0.3-tls

docker push crizstian/booking-service-go:v0.3-tls
