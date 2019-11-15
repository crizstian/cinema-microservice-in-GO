#!/usr/bin/env bash

docker rm -f cinemas-base-image:alpine-v0.1-tls

docker rmi cinemas-base-image:alpine-v0.1-tls

docker image prune

docker volume prune

docker build -t cinemas-base-image:alpine-v0.1-tls .

docker tag cinemas-base-image:alpine-v0.1-tls crizstian/cinemas-base-image:alpine-v0.1-tls

docker push crizstian/cinemas-base-image:alpine-v0.1-tls
