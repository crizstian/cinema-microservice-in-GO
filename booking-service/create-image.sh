#!/usr/bin/env bash

docker rm -f booking-service-go:v0.3

docker rmi booking-service-go:v0.3

docker image prune

docker volume prune

docker build -t booking-service-go:v0.3 .

docker tag booking-service-go:v0.3 crizstian/booking-service-go:v0.3

docker push crizstian/booking-service-go:v0.3
