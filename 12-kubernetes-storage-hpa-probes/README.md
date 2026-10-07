# Kubernetes Storage, HPA and Probes

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Class session 13. Lecture material: [`session-13-storage-hpa-probes`](https://github.com/Nency-Ravaliya/devops-heros/tree/main/session-13-storage-hpa-probes)
in the course repo. Every command was run in a real terminal on my Mac against a
single-node minikube cluster, and every screenshot in this folder is that terminal.

## Homework tasks → where they are

| Task | What was asked | Folder |
|---|---|---|
| 1 | Document emptyDir, hostPath, PV, PVC, StorageClass, dynamic provisioning, with practical examples | [`01-kubernetes-volumes/`](01-kubernetes-volumes/) |
| 2 | HPA hands-on: deploy, configure HPA, verify, load generator, increase load, observe CPU and Pod scaling | [`02-hpa/`](02-hpa/) |
| 3 | Session 13 mini project | [`04-mini-project/`](04-mini-project/) |
| (lecture) | Liveness / readiness / startup probes | [`03-probes/`](03-probes/) |

## Folder structure

```text
12-kubernetes-storage-hpa-probes/
├── 01-kubernetes-volumes/
│   ├── 01-emptydir-hostpath/     emptydir-pod.yaml, hostpath-pod.yaml
│   ├── 02-persistent-storage/    pv.yaml, pvc.yaml (fixed), pod.yaml
│   ├── 03-storageclass/          pvc.yaml
│   └── README.md
├── 02-hpa/                       deployment.yaml, service.yaml, hpa.yaml, README.md
├── 03-probes/                    liveness.yaml, readiness.yaml, startup.yaml, README.md
├── 04-mini-project/              namespace, pvc, deployment, service, hpa YAMLs, README.md
└── README.md
```

Each folder has a `screenshots/` directory, and its README walks through them in order.

## Environment

- macOS (Apple Silicon), Docker Desktop, minikube v1.39.0 on the docker driver,
  Kubernetes v1.37.0, one node.
- Addons used: `metrics-server` (enabled during the HPA task, on screen),
  `storage-provisioner` and `default-storageclass` (minikube defaults).
- With the docker driver the "node" is the minikube container, so files on the node
  (hostPath, PV data) are read with `minikube ssh`, and Services are reached with
  `kubectl port-forward`.
- The probes demo ran in its own namespace (`probes-lab`) so it could run alongside the
  HPA demo in `default`. The mini project uses its own `production-webapp` namespace, as
  the notes intend.

## Problems found in the lecture material

| Where | What happened | Fix |
|---|---|---|
| `02-persistent-storage/pvc.yaml` | PVC bound to a new dynamically created volume instead of `student-pv` | `storageClassName: ""` on the claim ([details](01-kubernetes-volumes/README.md#problem-found-the-pvc-from-the-notes-did-not-bind-to-student-pv)) |
| Probes "try breaking it" | `kubectl apply` of a changed probe is `Forbidden` because a Pod's spec is immutable | delete and recreate the Pod ([details](03-probes/README.md#problem-found-kubectl-apply-is-rejected)) |
| Probes debugging | `wget` isn't in the `nginx:1.27` image | used `curl` |
| HPA notes | metrics-server is enabled *after* the first `kubectl top`, which fails | kept the order to show the error, then enabled it |
| Mini project | one load generator spread over 2 replicas peaks at 41%, under the 50% target, so nothing scales | added two more generators, as the "increase load" step suggests |
