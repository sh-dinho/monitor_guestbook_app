import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";

export class RedisSlave extends pulumi.ComponentResource {
    public readonly service: k8s.core.v1.Service;

    constructor(name: string, masterService: pulumi.Output<string>, opts?: pulumi.ComponentResourceOptions) {
        super("guestbook:RedisSlave", name, {}, opts);

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
