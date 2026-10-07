# Scaler DevOps — Homework

Homework for the Scaler DevOps sessions. Class material and exercises come from
[Nency-Ravaliya/devops-heros](https://github.com/Nency-Ravaliya/devops-heros).

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Every command output in this repo was actually run on my machine and pasted in — nothing
is copied from notes.

## Contents

| # | Topic | Covers |
|---|---|---|
| 1 | [Linux Fundamentals](01-linux-fundamentals/) | soft vs hard links, `adduser` vs `useradd`, `journalctl`, command cheat sheet |
| 2 | [Shell Scripting](02-shell-scripting/) | `sysinfo.sh` — system report script with `read -p`, `mkdir`, `touch`, `>` |
| 3 | [Networking](03-networking/) | `ip`, `ss`, `dig`, `ping`, `traceroute`, `curl`, `tcpdump` |
| 4 | [Git / GitHub](04-git-github/) | `commit -a -m` vs `commit -m`, `cherry-pick` |
| 5 | [Docker: Hello World](05-docker-hello-world/) | six containerised apps — Node, Python, Java, Apache, nginx, React |
| 6 | [Docker Multi-Stage](06-docker-multistage/) | multi-stage build on port 8080, size comparison, three app types |
| 7 | [Docker Networking & Volumes](07-docker-network-volume/) | custom networks, host network, bind mounts, overlay |
| 8 | [Kubernetes Fundamentals](08-kubernetes-fundamentals/) | minikube cluster, control plane vs node components |
| 9 | [Pods, ReplicaSets, Deployments](09-kubernetes-pods-replicasets-deployments/) | self-healing, scaling, rolling update, `rollout undo` |
| 10 | [Kubernetes Networking & Services](10-kubernetes-networking-services/) | ClusterIP, NodePort, LoadBalancer, ExternalName, headless |
| 11 | [Ingress, ConfigMaps & Secrets](11-kubernetes-ingress-configmaps-secrets/) | config injection, base64 secrets, path-based routing |
| 12 | [Storage, HPA & Probes](12-kubernetes-storage-hpa-probes/) | emptyDir, hostPath, PV/PVC, StorageClass, HPA under load, liveness/readiness/startup probes |
| 13 | [Kubernetes Troubleshooting](13-kubernetes-troubleshooting/) | get/describe/logs/exec/events/explain/top, CrashLoopBackOff, ImagePullBackOff, Pending, DNS, triage scenarios |
| 14 | [Helm](14-helm/) | create, install, upgrade, history, rollback, repo/search, values files, rollback workflow |
| 15 | [CI/CD & GitHub Actions](15-github-actions/) | workflows, jobs, runners, secrets, artifacts, build/test pipeline, Dockerfile + CD stage (run locally with `act`) |
| 16 | [CI/CD & DevSecOps](16-devsecops/) | bandit (SAST), pip-audit (SCA), gitleaks, Trivy image gate, k8s deploy, full local pipeline |
| 17 | [Terraform & IaC](17-terraform-iac/) | init/fmt/validate/plan/apply/show/output/destroy, S3 demo on AWS, AWS services research |
| 18 | [Cloud & Terraform in Action](18-cloud-terraform/) | VPC, subnets, route tables, security groups, EC2 + S3 on AWS, state and dependencies |
| 19 | [Monitoring, Observability & GitOps](19-monitoring-observability-gitops/) | Prometheus, alert rules, Grafana, logs/metrics/traces, Argo CD sync and self-heal |
| 20 | [Final DevOps Project](20-final-devops-project/) | TaskBoard: Compose, tests, Docker, Helm on minikube, Ingress, HPA, troubleshooting, Terraform EKS on AWS |

Folder numbers run one behind the class session numbers: class sessions 1 and 2 were both
Linux and share folder 1, so folder 12 is class session 13 and folder 20 is class session 21.
Everything created on AWS (sections 17, 18 and 20) was destroyed straight after its
screenshots were taken.

## Environment

Everything was run on macOS (Apple Silicon) with Docker Desktop. The Kubernetes
sections use a single-node minikube cluster (v1.39.0, Kubernetes v1.37.0) on the
`docker` driver.

Because the minikube node sits on an internal Docker network that macOS cannot route
to, the reachability checks in sections 10 and 11 go through `kubectl port-forward`
rather than the node IP. That is called out in each section rather than glossed over.

Because `ip`, `ss`, `journalctl`, `adduser` and friends are Linux-only, the Linux and
networking tasks were done inside containers rather than faked:

| Task | Where it ran |
|---|---|
| Links, git, shell script | directly on macOS |
| `adduser` / `useradd` / `journalctl` | [Ubuntu 22.04 + systemd container](01-linux-fundamentals/ubuntu-lab/) |
| `ip`, `ss`, `dig`, `tcpdump` | `nicolaka/netshoot` container |
| All Docker tasks | Docker Desktop |

Where macOS behaves differently from Linux — `--network host` being the Docker VM rather
than the Mac, for instance — that is called out in the relevant write-up instead of
glossed over.

## Host ports used

Kept in one block so every app can run at once without clashing with anything already
listening on 3000, 5000 or 8080.

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
