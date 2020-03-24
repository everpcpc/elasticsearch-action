#!/bin/bash

set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

docker network create elastic

mkdir -p /es/plugins/
mkdir -p /es/config/

docker run --rm \
  --network=elastic \
  --entrypoint=tar \
  docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
  -c -C /usr/share/elasticsearch/ config | tar x -C /es/

chown -R 1000:1000 /es/

if [[ ! -z $PLUGINS ]]; then
  docker run --rm \
    --network=elastic \
    -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
    -v /es/config/:/usr/share/elasticsearch/config/ \
    --entrypoint=/usr/share/elasticsearch/bin/elasticsearch-plugin \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
    install ${PLUGINS/\\n/ } --batch
fi

docker run \
  --rm \
  --env "node.name=es1" \
  --env "cluster.name=docker-elasticsearch" \
  --env "cluster.initial_master_nodes=es1" \
  --env "discovery.seed_hosts=es1" \
  --env "cluster.routing.allocation.disk.threshold_enabled=false" \
  --env "bootstrap.memory_lock=true" \
  --env "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
  --env "xpack.security.enabled=false" \
  --env "xpack.license.self_generated.type=basic" \
  --ulimit nofile=65536:65536 \
  --ulimit memlock=-1:-1 \
  --publish "9200:9200" \
  --network=elastic \
  --name="es1" \
  -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
  -v /es/config/:/usr/share/elasticsearch/config/ \
  docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}

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
