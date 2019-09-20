#!/usr/bin/env bash

docker rm -f payment-service-go:v0.1

docker rmi payment-service-go:v0.1

docker image prune

docker volume prune

docker build -t payment-service-go:v0.1 .

docker tag payment-service-go:v0.1 crizstian/payment-service-go:v0.1

docker push crizstian/payment-service-go:v0.1
