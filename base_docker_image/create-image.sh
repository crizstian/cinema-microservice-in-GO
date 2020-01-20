#!/usr/bin/env bash

docker rm -f cinemas-base-image:alpine-v0.2

docker rmi cinemas-base-image:alpine-v0.2

docker image prune -f

docker volume prune -f

docker build -t cinemas-base-image:alpine-v0.2 .

docker tag cinemas-base-image:alpine-v0.2 crizstian/cinemas-base-image:alpine-v0.2

docker push crizstian/cinemas-base-image:alpine-v0.2
