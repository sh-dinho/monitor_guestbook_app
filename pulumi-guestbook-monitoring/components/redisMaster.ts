import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export class RedisMaster extends pulumi.ComponentResource {
    public readonly service: k8s.core.v1.Service;

    constructor(name: string, opts?: pulumi.ComponentResourceOptions) {
        super("guestbook:RedisMaster", name, {}, opts);

        const labels = { app: name };

        const deployment = new k8s.apps.v1.Deployment(`${name}-dep`, {
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

        this.service = new k8s.core.v1.Service(`${name}-svc`, {
            metadata: { labels },
            spec: {
                selector: labels,
                ports: [{ port: 6379 }]
            }
        }, { parent: this });

        this.registerOutputs();
    }
}
