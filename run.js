const path = require('path');
const core = require('@actions/core');
const shell = require('shelljs');

const volumes = path.join(__dirname, 'v');
const config_dir = path.join(volumes, 'config');
const plugin_dir = path.join(volumes, 'plugins');

try {
    const version = core.getInput('version');
    const plugins = core.getInput('plugins').replace(/\n/g, ' ');
    console.log(`Elastic version: ${version}`);

    shell.set('-e');
    shell.exec('docker network create elastic');
    shell.mkdir(volumes);
    shell.chmod('0777', volumes);
    shell.exec(`docker run --rm \
        --network=elastic \
        --user=1000 \
        --entrypoint=cp \
        -v ${volumes}:/v/ \
        docker.elastic.co/elasticsearch/elasticsearch:${version} \
        -r '/usr/share/elasticsearch/{config,plugins}' /v/
    `);

    if (plugins) {
        shell.exec(`docker run --rm \
            --network=elastic \
            --user=1000 \
            -v ${plugin_dir}:/usr/share/elasticsearch/plugins/ \
            -v ${config_dir}:/usr/share/elasticsearch/config/ \
            --entrypoint=/usr/share/elasticsearch/bin/elasticsearch-plugin \
            docker.elastic.co/elasticsearch/elasticsearch:${version} \
            install ${plugins} --batch
        `);
    }
    shell.exec(`docker run --rm \
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
        -v ${plugin_dir}:/usr/share/elasticsearch/plugins/ \
        -v ${config_dir}:/usr/share/elasticsearch/config/ \
        docker.elastic.co/elasticsearch/elasticsearch:${version}
    `)

    shell.exec(`docker run --rm \
        --network elastic \
        appropriate/curl \
        --max-time 120 \
        --retry 120 \
        --retry-delay 1 \
        --retry-connrefused \
        --show-error \
        --silent \
        http://es1:9200
    `);

    const time = (new Date()).toTimeString();
    core.setOutput("time", time);
} catch (error) {
    core.setFailed(error.message);
}