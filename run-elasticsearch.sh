#!/bin/bash

set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

docker network create elastic

mkdir -p /usr/share/elasticsearch/plugins/
mkdir -p /usr/share/elasticsearch/config/

docker run --rm \
  --network=elastic \
  --entrypoint=tar \
  docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
  -c -C /usr/share/elasticsearch/ config | tar x -C /usr/share/elasticsearch/

chown -R 1000:1000 /usr/share/elasticsearch/plugins/

if [[ ! -z $PLUGINS ]]; then
  docker run --rm \
    --network=elastic \
    --use=1000 \
    -v /usr/share/elasticsearch/plugins/:/usr/share/elasticsearch/plugins/ \
    -v /usr/share/elasticsearch/config/:/usr/share/elasticsearch/config/ \
    --entrypoint=/usr/share/elasticsearch/bin/elasticsearch-plugin \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
    install ${PLUGINS/\\n/ } --batch
fi

docker run \
  --network elastic \
  --rm \
  appropriate/curl \
  --max-time 120 \
  --retry 120 \
  --retry-delay 1 \
  --retry-connrefused \
  --show-error \
  --silent \
  http://es1:9200

sleep 10

echo "Elasticsearch up and running"
