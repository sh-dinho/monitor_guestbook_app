#!/bin/bash

echo "Creating Pulumi Guestbook + Monitoring project..."

# Root folder
mkdir -p pulumi-guestbook-monitoring
cd pulumi-guestbook-monitoring

# Pulumi project files
cat <<EOF > Pulumi.yaml
name: pulumi-guestbook-monitoring
runtime: nodejs
description: Guestbook app with Prometheus + Grafana monitoring
EOF

cat <<EOF > package.json
{
  "name": "pulumi-guestbook-monitoring",
  "dependencies": {
    "@pulumi/pulumi": "^3.0.0",
    "@pulumi/kubernetes": "^4.0.0"
  }
}
EOF

mkdir -p components monitoring

# ---------------------------
# COMPONENTS
# ---------------------------

# Frontend component
cat <<EOF > components/frontend.ts
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export class Frontend extends pulumi.ComponentResource {
    public readonly service: k8s.core.v1.Service;

    constructor(name: string, opts?: pulumi.ComponentResourceOptions) {
        super("guestbook:Frontend", name, {}, opts);

        const labels = { app: name };

        const deployment = new k8s.apps.v1.Deployment(\`\${name}-dep\`, {
            metadata: { labels },
            spec: {
                selector: { matchLabels: labels },
                replicas: 2,
                template: {
                    metadata: { labels },
                    spec: {
                        containers: [
                            {
                                name: "frontend",
                                image: "gcr.io/google-samples/gb-frontend:v5",
                                ports: [{ containerPort: 80 }],
                                env: [{ name: "METRICS_PORT", value: "9090" }]
                            }
                        ]
                    }
                }
            }
        }, { parent: this });

        this.service = new k8s.core.v1.Service(\`\${name}-svc\`, {
            metadata: {
                labels,
                annotations: {
                    "prometheus.io/scrape": "true",
                    "prometheus.io/port": "9090",
                    "prometheus.io/path": "/metrics"
                }
            },
            spec: {
                selector: labels,
                ports: [{ port: 80, targetPort: 80 }]
            }
        }, { parent: this });

        this.registerOutputs();
    }
}
EOF

# Redis master component
cat <<EOF > components/redisMaster.ts
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export class RedisMaster extends pulumi.ComponentResource {
    public readonly service: k8s.core.v1.Service;

    constructor(name: string, opts?: pulumi.ComponentResourceOptions) {
        super("guestbook:RedisMaster", name, {}, opts);

        const labels = { app: name };

        const deployment = new k8s.apps.v1.Deployment(\`\${name}-dep\`, {
            metadata: { labels },
            spec: {
                selector: { matchLabels: labels },
                replicas: 1,
                template: {
                    metadata: { labels },
                    spec: {
                        containers: [
                            {
                                name: "redis-master",
                                image: "redis",
                                ports: [{ containerPort: 6379 }]
                            }
                        ]
                    }
                }
            }
        }, { parent: this });

        this.service = new k8s.core.v1.Service(\`\${name}-svc\`, {
            metadata: { labels },
            spec: {
                selector: labels,
                ports: [{ port: 6379 }]
            }
        }, { parent: this });

        this.registerOutputs();
    }
}
EOF

# Redis slave component
cat <<EOF > components/redisSlave.ts
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export class RedisSlave extends pulumi.ComponentResource {
    public readonly service: k8s.core.v1.Service;

    constructor(name: string, masterService: pulumi.Output<string>, opts?: pulumi.ComponentResourceOptions) {
        super("guestbook:RedisSlave", name, {}, opts);

        const labels = { app: name };

        const deployment = new k8s.apps.v1.Deployment(\`\${name}-dep\`, {
            metadata: { labels },
            spec: {
                selector: { matchLabels: labels },
                replicas: 2,
                template: {
                    metadata: { labels },
                    spec: {
                        containers: [
                            {
                                name: "redis-slave",
                                image: "gcr.io/google_samples/gb-redisslave:v3",
                                env: [
                                    { name: "GET_HOSTS_FROM", value: "dns" },
                                    { name: "REDIS_MASTER_SERVICE_HOST", value: masterService }
                                ],
                                ports: [{ containerPort: 6379 }]
                            }
                        ]
                    }
                }
            }
        }, { parent: this });

        this.service = new k8s.core.v1.Service(\`\${name}-svc\`, {
            metadata: { labels },
            spec: {
                selector: labels,
                ports: [{ port: 6379 }]
            }
        }, { parent: this });

        this.registerOutputs();
    }
}
EOF

# ---------------------------
# MONITORING
# ---------------------------

# Prometheus
cat <<EOF > monitoring/prometheus.ts
import * as k8s from "@pulumi/kubernetes";

export const prometheus = new k8s.helm.v3.Chart("prometheus", {
    chart: "kube-prometheus-stack",
    version: "58.3.0",
    fetchOpts: { repo: "https://prometheus-community.github.io/helm-charts" },
    namespace: "monitoring",
    values: {
        prometheus: {
            prometheusSpec: {
                serviceMonitorSelectorNilUsesHelmValues: false
            }
        }
    }
});
EOF

# Grafana
cat <<EOF > monitoring/grafana.ts
import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export const grafanaService = new k8s.core.v1.Service("grafana-lb", {
    metadata: {
        namespace: "monitoring",
        name: "grafana-lb"
    },
    spec: {
        type: "LoadBalancer",
        ports: [{ port: 80, targetPort: 3000 }],
        selector: { "app.kubernetes.io/name": "grafana" }
    }
});

export const grafanaPassword = pulumi
    .output(k8s.core.v1.Secret.get("grafana", "monitoring/grafana"))
    .apply(s => Buffer.from(s.data["admin-password"], "base64").toString());
EOF

# ---------------------------
# MAIN INDEX.TS
# ---------------------------

cat <<EOF > index.ts
import { Frontend } from "./components/frontend";
import { RedisMaster } from "./components/redisMaster";
import { RedisSlave } from "./components/redisSlave";
import * as monitoring from "./monitoring/grafana";

const frontend = new Frontend("frontend");
const redisMaster = new RedisMaster("redis-master");
const redisSlave = new RedisSlave("redis-slave", redisMaster.service.metadata.name);

export const grafanaUrl = monitoring.grafanaService.status.loadBalancer.ingress[0].hostname.apply(
    host => \`http://\${host}\`
);

export const grafanaPassword = monitoring.grafanaPassword;
export const grafanaUser = "admin";
EOF

echo "Project created successfully!"
