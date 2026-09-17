# Kubernetes Ingress, ConfigMaps and Secrets

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Configuration and routing for a two-service app: non-sensitive settings in a ConfigMap,
credentials in a Secret, and one NGINX Ingress putting both services behind a single
entry point.

Any credential in these manifests is a lab placeholder, not a real secret.

> **Status:** in progress. Manifests, output blocks and screenshots below are placeholders.

## Folder structure

```text
11-kubernetes-ingress-configmaps-secrets/
├── 01-configmap/
├── 02-secret/
├── 03-ingress/
└── README.md
```

## All three at a glance

| # | Object | Holds | Delivered to the pod as | Encoded |
|---|---|---|---|---|
| 1 | ConfigMap | environment, log level, port | env vars or a mounted file | no |
| 2 | Secret | database user, password, db name | env vars or a mounted file | base64 |
| 3 | Ingress | host and path routing rules | handled by the controller | n/a |

---

## 1. ConfigMap

_Pending._

![ConfigMap](01-configmap/configmap_24BCS10244.png)

## 2. Secret

_Pending._

![Secret](02-secret/secret_24BCS10244.png)

## 3. Ingress

_Pending._

![Ingress](03-ingress/ingress_24BCS10244.png)
