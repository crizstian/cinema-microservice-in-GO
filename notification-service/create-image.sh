#!/usr/bin/env bash

docker rm -f notification-service-go:v0.2

docker rmi notification-service-go:v0.2

docker image prune

docker volume prune

docker build -t notification-service-go:v0.2 .

docker tag notification-service-go:v0.2 crizstian/notification-service-go:v0.2

docker push crizstian/notification-service-go:v0.2
