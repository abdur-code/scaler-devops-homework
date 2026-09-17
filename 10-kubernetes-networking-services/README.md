# Kubernetes Networking & Services

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

The five Service types, each backed by the same nginx Deployment so the difference between
them is only in how traffic reaches the pods.

> **Status:** in progress. Manifests, output blocks and screenshots below are placeholders.

## Folder structure

```text
10-kubernetes-networking-services/
├── 01-clusterip/
├── 02-nodeport/
├── 03-loadbalancer/
├── 04-externalname/
├── 05-headless/
└── README.md
```

## All five at a glance

| # | Type | Reachable from | Gets a virtual IP | Typical use |
|---|---|---|---|---|
| 1 | ClusterIP | inside the cluster only | yes | service-to-service calls |
| 2 | NodePort | any node IP on a high port | yes | local or bare-metal access |
| 3 | LoadBalancer | the internet, via a cloud LB | yes | public traffic |
| 4 | ExternalName | inside the cluster, as a DNS alias | no | pointing at an external host |
| 5 | Headless | inside the cluster, per-pod | no (`clusterIP: None`) | StatefulSets |

---

## 1. ClusterIP

_Pending._

![ClusterIP](01-clusterip/clusterip-service_24BCS10244.png)

## 2. NodePort

_Pending._

![NodePort](02-nodeport/nodeport-service_24BCS10244.png)

## 3. LoadBalancer

_Pending._

![LoadBalancer](03-loadbalancer/loadbalancer-service_24BCS10244.png)

## 4. ExternalName

_Pending._

![ExternalName](04-externalname/externalname-service_24BCS10244.png)

## 5. Headless

_Pending._

![Headless](05-headless/headless-service_24BCS10244.png)
