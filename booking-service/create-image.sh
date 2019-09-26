#!/usr/bin/env bash

docker rm -f booking-service-go:v0.1

docker rmi booking-service-go:v0.1

docker image prune

docker volume prune

docker build -t booking-service-go:v0.1 .

docker tag booking-service-go:v0.1 crizstian/booking-service-go:v0.1

docker push crizstian/booking-service-go:v0.1
