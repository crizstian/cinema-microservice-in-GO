#!/usr/bin/env bash

docker rm -f movies-service-go:v0.3

docker rmi movies-service-go:v0.3

docker image prune

docker volume prune

docker build -t movies-service-go:v0.3 .

docker tag movies-service-go:v0.3 crizstian/movies-service-go:v0.3

docker push crizstian/movies-service-go:v0.3
