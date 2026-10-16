# Kubernetes Fundamentals

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

A single-node Kubernetes cluster running locally with minikube, and what each piece of it
does. I ran every command below on my machine and pasted in the output.

The images in the folder are rendered from the terminal transcripts captured during these
runs. They hold the same text as the blocks below.

## Environment

| | |
|---|---|
| Host | macOS (Darwin 27.0), Apple Silicon (arm64) |
| minikube | v1.39.0 |
| Driver | `docker` (Docker Desktop) |
| Kubernetes | v1.37.0 |
| Container runtime | containerd 2.3.4 |
| Node OS | Debian GNU/Linux 12 (bookworm), kernel 7.0.12-linuxkit |

## 1. Starting the cluster

```bash
minikube start --driver=docker
```

minikube supports several drivers: `hyperkit`, `virtualbox`, `qemu` and `docker`. The
`docker` driver runs the whole Kubernetes node as a container on Docker Desktop instead of
booting a separate virtual machine. It starts faster, uses less memory, and on Apple
Silicon it avoids a second layer of virtualisation.

The trade-off shows up later. The node gets an address on a Docker-internal network that
macOS has no route to, so sections 10 and 11 reach services through `kubectl port-forward`
instead of the node IP. That comes from this driver and not from Kubernetes.

```text
$ minikube status
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

This is four separate checks:

- host: the container running the node is up
- kubelet: the agent on the node that starts and stops containers
- apiserver: the front door, since every `kubectl` command is an HTTPS call to it
- kubeconfig: my local `~/.kube/config` is pointed at this cluster

The last one is a client-side check. `kubeconfig: Configured` means my laptop knows where
the cluster is and holds credentials for it. A cluster can be healthy while `kubectl`
fails because the context points somewhere else.

```text
$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION            CONTAINER-RUNTIME
minikube   Ready    control-plane   17m   v1.37.0   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   7.0.12-linuxkit (arm64)   containerd://2.3.4
```

There is one node with the `control-plane` role and no separate workers, so the control
plane and my workloads share a machine. A production cluster separates them, and
control-plane nodes usually carry a taint that keeps ordinary pods off. minikube removes
that taint, which is why the things I deploy in later sections get scheduled at all.

`EXTERNAL-IP` is `<none>`: nothing outside the Docker network can reach this node directly.

The runtime is `containerd://`, not `docker://`. Docker Desktop provides the machine and
containerd runs the containers inside it. Kubernetes removed its built-in Docker support in
v1.24, and most clusters use containerd now. Docker itself has used containerd under the
hood for years, so dropping built-in Docker support removed a translation layer and no
feature.

```text
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:55697
CoreDNS is running at https://127.0.0.1:55697/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

The API server answers on `127.0.0.1:55697`, a random high port that Docker forwarded from
the node container to my Mac. `kubectl` works from the host only because of that forwarded
port. It is not 6443, the usual API server port, because 6443 is the port inside the node
and Docker published it to a free one outside.

![minikube cluster status and node detail](cluster-setup_24BCS10244.png)

### What I understood

The word "cluster" hides how many separate things have to line up. The node container has
to be running, the kubelet inside it has to be up, the API server has to be serving, and my
laptop has to hold a valid context pointing at a forwarded port. `minikube status` checks
all four because a failure in any one of them looks the same from `kubectl`: a timeout.

The driver choice mattered too. Picking `docker` gave me a faster start and cost me direct
network access to the node, and that decision is behind every port-forward in the two
sections that follow.

## 2. Control plane components

```text
$ kubectl get pods -n kube-system
NAME                               READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-lzrvr           1/1     Running   0          16m
etcd-minikube                      1/1     Running   0          17m
kindnet-ddmch                      1/1     Running   0          16m
kube-apiserver-minikube            1/1     Running   0          17m
kube-controller-manager-minikube   1/1     Running   0          17m
kube-proxy-wc2n5                   1/1     Running   0          16m
kube-scheduler-minikube            1/1     Running   0          17m
storage-provisioner                1/1     Running   0          17m
```

Kubernetes runs its own control plane as pods on the cluster it manages.

| Pod | Role | Scope |
|---|---|---|
| `kube-apiserver` | the only component that talks to etcd; everything else talks to it | control plane |
| `etcd` | key-value store holding the entire cluster state | control plane |
| `kube-scheduler` | decides which node an unscheduled pod lands on | control plane |
| `kube-controller-manager` | runs the reconcile loops (ReplicaSet, node, endpoints, …) | control plane |
| `kube-proxy` | programs iptables on each node so Service IPs route to pods | per node |
| `coredns` | in-cluster DNS; resolves Service names | add-on |
| `kindnet` | the CNI plugin; gives every pod an IP and connects them | add-on |
| `storage-provisioner` | fulfils PersistentVolumeClaims on minikube | add-on |

The split took me a moment to see. The first four are the control plane and exist once per
cluster. `kube-proxy` and `kindnet` are per-node: on a multi-node cluster there would be
one of each on every worker, scheduled by a DaemonSet. Here there is one node, so there is
one of everything and the split is hard to see.

The pod names show it, though. `etcd-minikube` and `kube-apiserver-minikube` have the node
name appended because they are static pods, defined by manifest files on the node's disk
and not by anything in the API. `coredns-559f6c778d-lzrvr` and `kindnet-ddmch` have random
suffixes because they are ordinary pods created by a Deployment and a DaemonSet.

Static pods exist to solve a bootstrapping problem: the API server cannot be created
through the API server. So the kubelet reads `/etc/kubernetes/manifests/` at start-up and
runs whatever it finds there directly, with no scheduler and no API involved.

### The path a command takes

With the table above, `kubectl apply -f pod.yml` in the next section goes like this:

1. `kubectl` sends an HTTPS request to the API server at `127.0.0.1:55697`
2. the API server authenticates it, validates the object, and writes it to etcd
3. the scheduler notices a pod with no node assigned and picks one (here, the only one)
4. the kubelet on that node sees a pod assigned to it and asks containerd to start it
5. kindnet gives the container an IP on the pod network
6. `kubectl get pods` reads the result back out through the API server

Nothing in that chain talks to anything else directly. Every component watches the API
server and reacts. That is why the control plane can lose a component and keep working in
a degraded way: if the scheduler dies, existing pods keep running and new ones sit
`Pending`.

```text
$ kubectl get svc -n kube-system
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   17m
```

`10.96.0.10` is the DNS server every pod in this cluster is configured to use. It shows up
again in sections 10 and 11, where every `nslookup` in those transcripts is answered by
this address. The Service is still called `kube-dns` for backwards compatibility, although
CoreDNS runs behind it.

Port 53 is exposed on both UDP and TCP. DNS normally uses UDP and falls back to TCP when a
response is too large for a single datagram, which is what happens with the headless
Service in section 10, where one lookup returns three A records.

![kube-system control plane pods and the cluster DNS service](cluster-components_24BCS10244.png)

### What I understood

Running the control plane as pods looks circular at first, but it means one set of
mechanisms manages everything. Health checks, restarts, resource limits and logging work
the same for `etcd` as for my nginx pods, and `kubectl logs -n kube-system` debugs the
platform the same way it debugs an app. Static pods resolve the circularity.

I also learned that Kubernetes is built from independent reconcile loops and has no
central orchestrator. Each controller watches for a gap between declared and actual state
and closes it. If I ask for three replicas and the ReplicaSet controller counts two, it
creates one, and nobody issues commands. That is why the ReplicaSet in the next section
heals itself, and why a dead scheduler degrades the cluster instead of breaking it.

## Notes

Straight after `minikube start` the node reported `NotReady`. It flipped to `Ready` once
the CNI plugin (`kindnet` here) was up and the node could hand out pod IPs. A node with no
working pod network is correctly considered not ready, because a pod scheduled onto it
would have nowhere to attach.

Add-ons are not part of Kubernetes. `storage-provisioner` and the ingress controller
enabled in section 11 are minikube conveniences, installed with `minikube addons enable`.
On a real cluster someone installs an equivalent, such as an EBS CSI driver or an
ingress-nginx Helm chart. Without one, `Ingress` objects route nothing.

To reproduce this section:

```bash
minikube start --driver=docker
minikube status
kubectl get nodes -o wide
kubectl cluster-info
kubectl get pods -n kube-system
kubectl get svc -n kube-system
```
