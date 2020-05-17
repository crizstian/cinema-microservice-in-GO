#!/usr/bin/env bash

docker rm -f cinemas-db:v0.4

docker rmi cinemas-db:v0.4

docker image prune -f

docker volume prune -f

docker build -t cinemas-db:v0.4 .

docker tag cinemas-db:v0.4 crizstian/cinemas-db:v0.4

docker push crizstian/cinemas-db:v0.4
