#!/usr/bin/env bash

docker rm -f movies-service-go:v0.1

docker rmi movies-service-go:v0.1

docker image prune

docker volume prune

docker build -t movies-service-go:v0.1 .

docker tag movies-service-go:v0.1 crizstian/movies-service-go:v0.1

docker push crizstian/movies-service-go:v0.1
