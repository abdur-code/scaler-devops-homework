# Scaler DevOps homework

Homework for the Scaler DevOps sessions. Class material and exercises come from
[Nency-Ravaliya/devops-heros](https://github.com/Nency-Ravaliya/devops-heros).

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Every command output in this repo was run on my machine and pasted in. Nothing is copied from notes.

## Contents

| # | Topic | Covers |
|---|---|---|
| 1 | [Linux fundamentals](01-linux-fundamentals/) | soft vs hard links, `adduser` vs `useradd`, `journalctl`, command cheat sheet |
| 2 | [Shell scripting](02-shell-scripting/) | `sysinfo.sh`, a system report script with `read -p`, `mkdir`, `touch`, `>` |
| 3 | [Networking](03-networking/) | `ip`, `ss`, `dig`, `ping`, `traceroute`, `curl`, `tcpdump` |
| 4 | [Git and GitHub](04-git-github/) | `commit -a -m` vs `commit -m`, `cherry-pick` |
| 5 | [Docker hello world](05-docker-hello-world/) | six containerised apps: Node, Python, Java, Apache, nginx, React |
| 6 | [Docker multi-stage](06-docker-multistage/) | multi-stage build on port 8080, size comparison, three app types |
| 7 | [Docker networking and volumes](07-docker-network-volume/) | custom networks, host network, bind mounts, overlay |
| 8 | [Kubernetes fundamentals](08-kubernetes-fundamentals/) | minikube cluster, control plane vs node components |
| 9 | [Pods, ReplicaSets and Deployments](09-kubernetes-pods-replicasets-deployments/) | self-healing, scaling, rolling update, `rollout undo` |
| 10 | [Kubernetes networking and Services](10-kubernetes-networking-services/) | ClusterIP, NodePort, LoadBalancer, ExternalName, headless |
| 11 | [Ingress, ConfigMaps and Secrets](11-kubernetes-ingress-configmaps-secrets/) | config injection, base64 secrets, path-based routing |
| 12 | [Storage, HPA and probes](12-kubernetes-storage-hpa-probes/) | emptyDir, hostPath, PV/PVC, StorageClass, HPA under load, liveness/readiness/startup probes |
| 13 | [Kubernetes troubleshooting](13-kubernetes-troubleshooting/) | get/describe/logs/exec/events/explain/top, CrashLoopBackOff, ImagePullBackOff, Pending, DNS, triage scenarios |
| 14 | [Helm](14-helm/) | create, install, upgrade, history, rollback, repo/search, values files, rollback workflow |
| 15 | [CI/CD and GitHub Actions](15-github-actions/) | workflows, jobs, runners, secrets, artifacts, build/test pipeline, Dockerfile + CD stage (run locally with `act`) |
| 16 | [CI/CD and DevSecOps](16-devsecops/) | bandit (SAST), pip-audit (SCA), gitleaks, Trivy image gate, k8s deploy, full local pipeline |
| 17 | [Terraform and IaC](17-terraform-iac/) | init/fmt/validate/plan/apply/show/output/destroy, S3 demo on AWS, AWS services research |
| 18 | [Cloud and Terraform in action](18-cloud-terraform/) | VPC, subnets, route tables, security groups, EC2 + S3 on AWS, state and dependencies |
| 19 | [Monitoring, observability and GitOps](19-monitoring-observability-gitops/) | Prometheus, alert rules, Grafana, logs/metrics/traces, Argo CD sync and self-heal |
| 20 | [Final DevOps project](20-final-devops-project/) | TaskBoard: Compose, tests, Docker, Helm on minikube, Ingress, HPA, troubleshooting, Terraform EKS on AWS |

Folder numbers run one behind the class session numbers: class sessions 1 and 2 were both
Linux and share folder 1, so folder 12 is class session 13 and folder 20 is class session 21.
Everything created on AWS (sections 17, 18 and 20) was destroyed straight after its
screenshots were taken.

## Environment

Everything was run on macOS (Apple Silicon) with Docker Desktop. The Kubernetes
sections use a single-node minikube cluster (v1.39.0, Kubernetes v1.37.0) on the
`docker` driver.

The minikube node sits on an internal Docker network that macOS cannot route to, so the
reachability checks in sections 10 and 11 go through `kubectl port-forward` instead of
the node IP. Each of those sections says so.

`ip`, `ss`, `journalctl`, `adduser` and the like are Linux-only, so I did the Linux and
networking tasks inside containers:

| Task | Where it ran |
|---|---|
| Links, git, shell script | directly on macOS |
| `adduser` / `useradd` / `journalctl` | [Ubuntu 22.04 + systemd container](01-linux-fundamentals/ubuntu-lab/) |
| `ip`, `ss`, `dig`, `tcpdump` | `nicolaka/netshoot` container |
| All Docker tasks | Docker Desktop |

Where macOS behaves differently from Linux, for example `--network host` giving the Docker
VM's network and not the Mac's, the relevant write-up says so.

## Host ports used

I gave each app its own host port so they can all run at once without clashing with
anything already listening on 3000, 5000 or 8080.

| Port | What |
|---|---|
| 8080 | multi-stage app (required by the task) |
| 8101 | nodejs-app |
| 8102 | python-app |
| 8103 | java-app |
| 8104 | Apache-app |
| 8105 | nginx-app |
| 8106 | React-app |
| 8107 | bind-mount nginx |
| 8108 | swarm service (overlay task) |

## Running everything

```bash
# section 2
cd 02-shell-scripting && ./sysinfo.sh && cd ..

# section 5
cd 05-docker-hello-world
docker build -t hello-node   nodejs-app
docker build -t hello-python python-app
docker build -t hello-java   java-app
docker build -t hello-apache Apache-app
docker build -t hello-nginx  nginx-app
docker build -t hello-react  React-app
cd ..

# section 6
docker build -t multistage-hello 06-docker-multistage/hello-multistage
docker run -d --name multistage-app -p 8080:3000 multistage-hello
```

Per-task build, run and cleanup commands are in each folder's README.

## Cleanup

```bash
docker rm -f hw-node hw-python hw-java hw-apache hw-nginx hw-react \
             multistage-app frontend backend database apache-port80 \
             bind-nginx ubuntu-lab netlab
docker network rm web-net app-net data-net
docker volume rm demo-vol
```
