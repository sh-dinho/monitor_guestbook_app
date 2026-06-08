import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export class Frontend extends pulumi.ComponentResource {
    public readonly service: k8s.core.v1.Service;

    constructor(name: string, opts?: pulumi.ComponentResourceOptions) {
        super("guestbook:Frontend", name, {}, opts);

        const labels = { app: name };

        const deployment = new k8s.apps.v1.Deployment(`${name}-dep`, {
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

        this.service = new k8s.core.v1.Service(`${name}-svc`, {
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
