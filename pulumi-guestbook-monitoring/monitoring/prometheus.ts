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
