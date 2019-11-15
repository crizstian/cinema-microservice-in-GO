#!/usr/bin/env bash

docker rm -f notification-service-go:v0.3-tls

docker rmi notification-service-go:v0.3-tls

docker image prune

docker volume prune

docker build -t notification-service-go:v0.3-tls .

docker tag notification-service-go:v0.3-tls crizstian/notification-service-go:v0.3-tls

docker push crizstian/notification-service-go:v0.3-tls
