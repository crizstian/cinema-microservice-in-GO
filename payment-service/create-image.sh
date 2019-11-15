#!/usr/bin/env bash

docker rm -f payment-service-go:v0.3-tls

docker rmi payment-service-go:v0.3-tls

docker image prune

docker volume prune

docker build -t payment-service-go:v0.3-tls .

docker tag payment-service-go:v0.3-tls crizstian/payment-service-go:v0.3-tls

docker push crizstian/payment-service-go:v0.3-tls
