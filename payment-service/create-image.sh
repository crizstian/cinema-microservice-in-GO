#!/usr/bin/env bash

docker rm -f payment-service-go:v0.3

docker rmi payment-service-go:v0.3

docker image prune

docker volume prune

docker build -t payment-service-go:v0.3 .

docker tag payment-service-go:v0.3 crizstian/payment-service-go:v0.3

docker push crizstian/payment-service-go:v0.3
