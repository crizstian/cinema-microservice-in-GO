#!/usr/bin/env bash

docker rm -f cinemas-web-server:v0.1

docker rmi cinemas-web-server:v0.1

docker image prune -f

docker volume prune -f

docker build -t cinemas-web-server:v0.1 .

docker tag cinemas-web-server:v0.1 crizstian/cinemas-web-server:v0.1

docker push crizstian/cinemas-web-server:v0.1
