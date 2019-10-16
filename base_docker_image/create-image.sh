#!/usr/bin/env bash

docker rm -f cinemas-base-image:alpine-v0.1

docker rmi cinemas-base-image:alpine-v0.1

docker image prune

docker volume prune

docker build -t cinemas-base-image:alpine-v0.1 .

docker tag cinemas-base-image:alpine-v0.1 crizstian/cinemas-base-image:alpine-v0.1

docker push crizstian/cinemas-base-image:alpine-v0.1
