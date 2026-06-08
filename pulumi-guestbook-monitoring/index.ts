import { Frontend } from "./components/frontend";
import { RedisMaster } from "./components/redisMaster";
import { RedisSlave } from "./components/redisSlave";
import * as monitoring from "./monitoring/grafana";

const frontend = new Frontend("frontend");
const redisMaster = new RedisMaster("redis-master");
const redisSlave = new RedisSlave("redis-slave", redisMaster.service.metadata.name);

export const grafanaUrl = monitoring.grafanaService.status.loadBalancer.ingress[0].hostname.apply(
    host => `http://${host}`
);

export const grafanaPassword = monitoring.grafanaPasswordOutput;
export const grafanaUser = "admin";
