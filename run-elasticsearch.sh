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
  --entrypoint=tar \
  docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
  -c -C /usr/share/elasticsearch/ config | tar x -C /usr/share/elasticsearch/


if [[ ! -z $PLUGINS ]]; then
  docker run --rm \
    -v /usr/share/elasticsearch/plugins/:/usr/share/elasticsearch/plugins/ \
    -v /usr/share/elasticsearch/config/:/usr/share/elasticsearch/config/ \
    --entrypoint=/usr/share/elasticsearch/bin/elasticsearch-plugin \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
    install ${PLUGINS/\\n/ } --batch
fi

NODES=${NODES-1}
for (( node=1; node<=$NODES; node++ ))
do
  port=$((9200 + $node - 1))
  docker run \
    --rm \
    --env "node.name=es${node}" \
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
    --publish "${port}:9200" \
    --detach \
    --network=elastic \
    --name="es${node}" \
    -v /usr/share/elasticsearch/plugins/:/usr/share/elasticsearch/plugins/:ro \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
done

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
