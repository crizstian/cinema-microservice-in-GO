#!/usr/bin/env bash

docker rm -f movies-service-go:v0.3-tls

docker rmi movies-service-go:v0.3-tls

docker image prune

docker volume prune

docker build -t movies-service-go:v0.3-tls .

docker tag movies-service-go:v0.3-tls crizstian/movies-service-go:v0.3-tls

docker push crizstian/movies-service-go:v0.3-tls
