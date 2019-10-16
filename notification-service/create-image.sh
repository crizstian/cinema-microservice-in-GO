#!/usr/bin/env bash

docker rm -f notification-service-go:v0.3

docker rmi notification-service-go:v0.3

docker image prune

docker volume prune

docker build -t notification-service-go:v0.3 .

docker tag notification-service-go:v0.3 crizstian/notification-service-go:v0.3

docker push crizstian/notification-service-go:v0.3
