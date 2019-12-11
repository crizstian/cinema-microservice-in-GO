## Movie Service

In order to run this microservice, is manadatory to have a mongodb database in replicaSet mode, to spin up a db cluster see [mongo replica set](https://github.com/Crizstian/mongo-replica-with-docker)

## Environment variables

**export DB_USER**=cristian

**export DB_PASS**=cristianPassword2017

**export DB_SERVERS**="192.168.99.100:27017,192.168.99.101:27017,192.168.99.102:27017"

**export DB_NAME**=movies

**export DB_REPLICA**=rs1

**export SERVICE_PORT**=8000

**export APP_NAME**=movie-service