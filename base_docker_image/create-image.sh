#!/usr/bin/env bash

docker rm -f cinemas-base-image:alpine-v0.2

docker rmi cinemas-base-image:alpine-v0.2

docker image prune

docker volume prune

docker build -t cinemas-base-image:alpine-v0.2 .

docker tag cinemas-base-image:alpine-v0.2 crizstian/cinemas-base-image:alpine-v0.2

docker push crizstian/cinemas-base-image:alpine-v0.2
