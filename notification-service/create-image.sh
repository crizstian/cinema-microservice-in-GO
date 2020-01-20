#!/usr/bin/env bash

docker rm -f notification-service-go:v0.4

docker rmi notification-service-go:v0.4

docker image prune -f

docker volume prune -f

docker build -t notification-service-go:v0.4 .

docker tag notification-service-go:v0.4 crizstian/notification-service-go:v0.4

docker push crizstian/notification-service-go:v0.4
