import * as k8s from "@pulumi/kubernetes";
import * as pulumi from "@pulumi/pulumi";
import { prometheus } from "./prometheus";

const config = new pulumi.Config();
// Get grafanaPassword from config or use default (kube-prometheus-stack default is 'prom-operator')
const grafanaPassword = config.get("grafanaPassword") || "prom-operator";

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
}, { dependsOn: prometheus });

// Export the Grafana password
export const grafanaPasswordOutput = pulumi.output(grafanaPassword);
