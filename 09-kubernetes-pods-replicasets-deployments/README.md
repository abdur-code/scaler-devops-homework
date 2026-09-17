# Kubernetes Pods, ReplicaSets and Deployments

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

The three core workload objects, built up in order — a bare Pod, a ReplicaSet that keeps a
set of Pods alive, and a Deployment that manages ReplicaSets so you get rolling updates and
rollbacks. Every command output below was run on my machine and pasted in.

The images in each folder are rendered from the terminal transcripts captured during
these runs — same text as the blocks below, just easier to scan.

## Folder structure

```text
09-kubernetes-pods-replicasets-deployments/
├── 01-pod/            pod.yml         pod_24BCS10244.png
├── 02-replicaset/     replicaset.yml  replicaset_24BCS10244.png
├── 03-deployment/     deployment.yml  deployment_24BCS10244.png
└── README.md
```

## All three at a glance

| # | Object | Manages | Survives a pod delete | Rolling updates |
|---|---|---|---|---|
| 1 | Pod | one set of containers | no | no |
| 2 | ReplicaSet | a fixed number of identical Pods | yes | no |
| 3 | Deployment | ReplicaSets | yes | yes |

All three manifests use the label `app: nginx`, so each task deletes its object before the
next one starts. Left running, the ReplicaSet would **adopt** the standalone Pod — its
selector matches — and create only two new pods instead of three.

---

## 1. Pod

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: nginx-pod
  labels:
    app: nginx

spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

```text
$ kubectl apply -f pod.yml
pod/nginx-pod created

$ kubectl get pods -o wide
NAME        READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
nginx-pod   1/1     Running   0          15s   10.244.0.3   minikube   <none>           <none>
```

The Pod got `10.244.0.3` — an address on the cluster's pod network, handed out by the CNI
plugin. It is not reachable from macOS; only from inside the cluster.

`describe` is trimmed here to the fields that matter:

```text
$ kubectl describe pod nginx-pod | head -25
Name:             nginx-pod
Namespace:        default
Node:             minikube/192.168.49.2
Labels:           app=nginx
Status:           Running
IP:               10.244.0.3
Containers:
  nginx:
    Container ID:   containerd://536ff65ba70075d899ed8a6a681563c2eb8eb271999098f39762f6dc23df89e8
    Image:          nginx:latest
    Image ID:       docker.io/library/nginx@sha256:d0d674272be3be36f9a13d79194fa0db5aa630ab3ede9bec459d12f67370aaef
    Port:           80/TCP
    State:          Running
    Ready:          True
    Restart Count:  0
```

The container ID is prefixed `containerd://`, not `docker://`. minikube uses containerd as
its runtime even though the *driver* is Docker — Docker Desktop provides the machine, and
containerd runs the containers inside it.

```text
$ kubectl logs nginx-pod | head -5
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
```

### The part that defines a Pod

```text
$ kubectl delete pod nginx-pod
pod "nginx-pod" deleted from default namespace

$ kubectl get pods
No resources found in default namespace.
```

Nothing brought it back. A bare Pod has no controller watching it, so deleting it is final
— and so is a node failure or an eviction. This is exactly the gap the next two objects
close, and it is why you almost never write a bare Pod in production.

![A bare Pod created, inspected and deleted — nothing recreates it](01-pod/pod_24BCS10244.png)

### What I understood

A Pod is the unit Kubernetes schedules, not a container. Everything in one Pod shares a
network namespace and an IP, which is why sidecar patterns work — two containers in a Pod
reach each other on `localhost`.

What I did not appreciate before running this is how completely unprotected a bare Pod is.
There is no controller watching it, so deleting it is final, and so is a node failure or an
eviction under memory pressure. `RESTARTS` counts a *container* crashing and being restarted
in place; it does nothing if the Pod object itself disappears. That gap is the entire reason
the next two objects exist.

---

## 2. ReplicaSet

```yaml
apiVersion: apps/v1
kind: ReplicaSet

metadata:
  name: nginx-rs

spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

`spec.selector.matchLabels` and `spec.template.metadata.labels` have to agree. The selector
is what the ReplicaSet counts; the template labels are what it stamps on the pods it makes.
If they disagree, it creates pods it cannot see and loops forever.

```text
$ kubectl get rs
NAME       DESIRED   CURRENT   READY   AGE
nginx-rs   3         3         3       8s

$ kubectl get pods -l app=nginx -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
nginx-rs-bl55r   1/1     Running   0          8s    10.244.0.40   minikube   <none>           <none>
nginx-rs-pmlb6   1/1     Running   0          8s    10.244.0.39   minikube   <none>           <none>
nginx-rs-pshbl   1/1     Running   0          8s    10.244.0.41   minikube   <none>           <none>
```

### Self-healing

```text
$ kubectl delete $(kubectl get pods -l app=nginx -o name | head -1)
pod "nginx-rs-bl55r" deleted from default namespace

$ kubectl get pods -l app=nginx
NAME             READY   STATUS    RESTARTS   AGE
nginx-rs-g7h5m   1/1     Running   0          7s
nginx-rs-pmlb6   1/1     Running   0          15s
nginx-rs-pshbl   1/1     Running   0          15s
```

Still three pods, but look at the ages. `bl55r` is gone and `g7h5m` is 7 seconds old while
the two survivors are 15. The controller noticed the count had dropped below `replicas: 3`
and created a replacement within seconds.

The replacement is a **new pod with a new name and a new IP** — not the old one restarted.
`RESTARTS` stays `0`. That is the whole reason Services exist: you cannot hardcode a pod IP
when the platform is free to replace pods underneath you.

### Scaling

```text
$ kubectl scale rs nginx-rs --replicas=5
replicaset.apps/nginx-rs scaled

$ kubectl get rs
NAME       DESIRED   CURRENT   READY   AGE
nginx-rs   5         5         5       21s
```

![The ReplicaSet replacing a deleted pod, then scaling to five](02-replicaset/replicaset_24BCS10244.png)

### What I understood

The ReplicaSet controller does not repair the pod I deleted — it creates a different one.
New name, new IP, `RESTARTS` still `0`. It reconciles a **count**, not an identity, and once
that clicked the design of the next section made sense: if the platform is free to replace
pods underneath me, no client can hold a pod IP, so something stable has to sit in front.
That something is a Service.

The selector is also easy to get wrong in a way that fails quietly. `spec.selector` is what
the ReplicaSet counts and `spec.template.metadata.labels` is what it stamps on new pods. If
they disagree it creates pods it cannot see, counts zero, and creates more forever. Related:
because this manifest and `pod.yml` share `app: nginx`, leaving the bare Pod running would
have let the ReplicaSet adopt it and create only two pods of its own.

---

## 3. Deployment

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: nginx-deployment

spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

```text
$ kubectl get deployment nginx-deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/3     3            3           1s

$ kubectl get rs,pods -l app=nginx
NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deployment-6946987795   3         3         3       1s

NAME                                    READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-6946987795-7r4zs   1/1     Running   0          1s
pod/nginx-deployment-6946987795-pz7mb   1/1     Running   0          1s
pod/nginx-deployment-6946987795-scrnc   1/1     Running   0          1s
```

I did not create a ReplicaSet — the Deployment did, named `nginx-deployment-6946987795`.
That suffix is a hash of the pod template, which matters in a moment.

Worth noting: `kubectl get deploy -l app=nginx` returns nothing. The label lives on the pod
*template*, not on the Deployment object, so the Deployment has to be fetched by name.

### Rolling update

```text
$ kubectl set image deployment/nginx-deployment nginx=nginx:1.26
deployment.apps/nginx-deployment image updated

$ kubectl rollout status deployment/nginx-deployment
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 old replicas are pending termination...
deployment "nginx-deployment" successfully rolled out
```

Trimmed — the real transcript repeats each line several times as it polls.

The progression is the point: new pods come up *before* old ones go away, a few at a time,
so the app never drops to zero capacity. That is the default `RollingUpdate` strategy.

```text
$ kubectl get rs -l app=nginx
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-6946987795   0         0         0       2s
nginx-deployment-69858744c4   3         3         3       1s
```

Two ReplicaSets now. The old one is scaled to **0 but not deleted** — that is what makes a
rollback instant. Kubernetes does not rebuild the previous version, it scales the old
ReplicaSet back up.

```text
$ kubectl rollout history deployment/nginx-deployment
deployment.apps/nginx-deployment
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

`CHANGE-CAUSE` is `<none>` because I used `kubectl set image` without recording an
annotation. In a real pipeline you would set `kubernetes.io/change-cause` so the history
says *why* each revision exists.

### Rollback

```text
$ kubectl rollout undo deployment/nginx-deployment
Warning: resource deployments/nginx-deployment was previously managed with 'kubectl apply'. Rolling back will not update the kubectl.kubernetes.io/last-applied-configuration annotation, which may cause unexpected behavior on future 'kubectl apply' operations.
deployment.apps/nginx-deployment rolled back

$ kubectl rollout status deployment/nginx-deployment
deployment "nginx-deployment" successfully rolled out
```

The warning is real and worth keeping rather than hiding. `rollout undo` changes the live
object but not the `last-applied-configuration` annotation that `kubectl apply` diffs
against. So the cluster is back on 1.25, but my `deployment.yml` on disk and the annotation
still describe the applied state — the next `kubectl apply` could quietly undo the
rollback. The clean fix in practice is to revert the manifest in git and re-apply, and let
`rollout undo` be the emergency lever.

![Rolling update to nginx 1.26, two ReplicaSets, then a rollback](03-deployment/deployment_24BCS10244.png)

### What I understood

A Deployment does not manage pods. It manages ReplicaSets, and *they* manage pods — three
layers, each adding exactly one capability. The hash suffix on
`nginx-deployment-6946987795` is computed from the pod template, so changing the image
produces a genuinely different ReplicaSet rather than mutating the existing one.

That is what makes rollback instant. The old ReplicaSet is scaled to zero and kept, so
`rollout undo` scales it back up instead of rebuilding anything. It also explains why
`kubectl get rs` shows two entries after an update and why old ones accumulate until
`revisionHistoryLimit` trims them.

Which reframes the warning above: `rollout undo` is a live-object operation, and my manifest
on disk never learns about it. So it belongs in the emergency toolkit — get the old version
back in seconds — while the durable fix is reverting the manifest in git.

---

## Notes

**Why three objects instead of one.** Each layer adds exactly one capability. A Pod runs
containers. A ReplicaSet keeps N of them alive. A Deployment manages successive
ReplicaSets so you can change the template without downtime. You can use the lower layers
directly, but in practice you write Deployments and let them create the rest.

**A ReplicaSet does not update pods.** Changing the image in `replicaset.yml` and
re-applying leaves the running pods untouched — the ReplicaSet only cares about the
*count*, not whether existing pods match the current template. That is precisely the gap
the Deployment fills.

**Reproducing this section.**

```bash
cd 01-pod        && kubectl apply -f pod.yml        && cd ..
cd 02-replicaset && kubectl apply -f replicaset.yml && cd ..
cd 03-deployment && kubectl apply -f deployment.yml && cd ..
```
