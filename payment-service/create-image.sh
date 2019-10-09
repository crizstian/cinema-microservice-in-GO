#!/usr/bin/env bash

docker rm -f payment-service-go:v0.2

docker rmi payment-service-go:v0.2

docker image prune

docker volume prune

docker build -t payment-service-go:v0.2 .

docker tag payment-service-go:v0.2 crizstian/payment-service-go:v0.2

docker push crizstian/payment-service-go:v0.2
