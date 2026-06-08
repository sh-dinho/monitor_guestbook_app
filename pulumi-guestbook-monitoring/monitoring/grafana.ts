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
