#!/usr/bin/env bash

docker rm -f booking-service-go:v0.4

docker rmi booking-service-go:v0.4

docker image prune

docker volume prune

docker build -t booking-service-go:v0.4 .

docker tag booking-service-go:v0.4 crizstian/booking-service-go:v0.4

docker push crizstian/booking-service-go:v0.4
