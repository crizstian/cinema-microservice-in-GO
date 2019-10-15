#!/usr/bin/env bash

function createKeyFile {
  openssl rand -base64 741 > $1
  chmod 600 $1
}

createKeyFile files/mongo-keyfile

docker rm -f cinemas-db:v0.2

docker rmi cinemas-db:v0.2

docker image prune

docker volume prune

docker build -t cinemas-db:v0.2 .

docker tag cinemas-db:v0.2 crizstian/cinemas-db:v0.2

docker push crizstian/cinemas-db:v0.2
