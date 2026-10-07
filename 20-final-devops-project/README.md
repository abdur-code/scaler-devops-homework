# Session 21: Final DevOps Project (TaskBoard)

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

This folder is the instructor's `session21-python` TaskBoard project (FastAPI + PostgreSQL +
React/nginx, Docker, Helm, Kubernetes). I ran the commands from its [README](https://github.com/Nency-Ravaliya/devops-heros/blob/main/session21-python/README.md)
section by section on my Mac, and every screenshot here comes from my own terminal. When a
command from the README failed, I took a screenshot of the failure, made the smallest fix to
my copy (each fix has a comment in the file), and ran it again. This file maps each section
of that README to my screenshots.

## README section → evidence

| README section | What I ran | Screenshots |
|---|---|---|
| §5 Docker Compose | `docker compose up --build`, curl :3000 / :8000, `down`, `down -v` | 01–07 |
| §6 Backend directly | venv, `pip install`, `alembic upgrade head`, `uvicorn`, curl | 08–16 |
| §7 Pytest | `pytest -q` | 17–18 |
| §8 Git | `git init/add/commit/branch -M main` (scratch copy) | 19–20 |
| §9–10 Docker images | `docker build` ×2, `docker run` backend | 21–25 |
| §11–12 GitHub Actions + Trivy | not run locally; they run on GitHub after a push | Pending |
| §13 Terraform (AWS) | `init`, `fmt`, `validate`, `plan`, `apply`, `update-kubeconfig`, `destroy`: see [terraform/](terraform/) | terraform/ 01–13 |
| §14–15 Namespace + Helm | `kubectl apply -f k8s/namespace.yaml`, `helm upgrade --install` | 26–32 |
| §19 Ingress (values-dev) | `helm upgrade --install … -f values-dev.yaml`, ingress check | 34–39 |
| §20 HPA | `kubectl get hpa -n taskboard` | 33, 35, 40 |
| §21–22 Monitoring | no commands in the README, so there was nothing to run | - |
| §23 Broken image | apply, `get pods`, `describe pod`, `get events`, fix | 41–46 |
| §24 Broken Service | apply, `get svc`, `get endpoints`, `get pods --show-labels`, fix | 47–52 |
| Part O final checks | `get pods`, `get svc`, `helm list`, `get hpa` | 53 |
| Cleanup | helm uninstall, delete namespace, `compose down -v`, images, venv | 54–55 |

## Folder structure

```text
20-final-devops-project/
├── README.md              this file
├── screenshots/           55 screenshots, numbered in run order
├── backend/               FastAPI, SQLAlchemy, Alembic, pytest
├── frontend/              React + Vite, served by nginx
├── docker-compose.yml
├── helm/taskboard/        Helm chart
├── k8s/namespace.yaml
├── troubleshooting/       broken-image.yaml, broken-service.yaml
├── monitoring/  scripts/  .github/workflows/ci-cd.yml
└── terraform/             §13: VPC + EKS on AWS, its own README and screenshots
```

## What I changed in the instructor's files

| File | Change | Why (details in the section below) |
|---|---|---|
| `docker-compose.yml` | `restart: on-failure` on `backend` | backend raced Postgres on first start (§5) |
| `backend/requirements.txt` | `psycopg[binary]` 3.2.3 → 3.2.10 | 3.2.3 has no wheel for Python 3.14 (§6) |
| `backend/tests/test_api.py` | autouse fixture that enters `with client:` | startup event never ran, so there was no `tasks` table (§7) |
| `helm/taskboard/templates/backend-service.yaml` | Service name → `backend` | nginx in the frontend image proxies to `backend:8000` (§15) |
| `helm/taskboard/templates/ingress.yaml` | `/api` → `backend:8000` | pointed at a non-existent `taskboard-backend:8080` (§19) |
| `troubleshooting/broken-image.yaml` | real image + `DATABASE_URL` | the lab's fix (§23) |
| `troubleshooting/broken-service.yaml` | real selector + `targetPort: 8000` | the lab's fix (§24) |

These Helm values were passed on the command line, not edited into files:
`--set monitoring.serviceMonitor.enabled=false`, `--set backend.image=taskboard-backend
--set backend.tag=local --set frontend.image=taskboard-frontend --set frontend.tag=local`, and
(last upgrade only) `--set hpa.enabled=true`.

## Environment and deviations

- macOS (Apple Silicon), Docker Desktop, minikube (docker driver) with the `ingress` and
  `metrics-server` addons, kubectl, helm, Homebrew Python **3.14**.
- Kubernetes work ran in namespace **`taskboard`** (the README's namespace). It was set as
  the default namespace of my terminal's kubeconfig, so sessions could run side by side.
  The only exception is screenshots 42 and 48: there I ran the README's troubleshooting
  commands exactly as written in a terminal with the normal kubeconfig (namespace `default`)
  to show what happens without `-n taskboard`.
- macOS has no `python` command, so I used `python3`. I put the venv outside the repo instead
  of `backend/.venv`, so nothing ends up in git. `$S` in the commands below is that scratch
  directory outside the repo.
- I tested the ingress without editing `/etc/hosts`:
  `kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 18210:80` plus
  `curl -H "Host: taskboard.local"`. To check the fixed `broken-service` I used port 18211.
  Ports 3000, 8000 and 5432 are the README's.
- Images run in minikube are the ones I built in §9–10 (`taskboard-*:local`). I loaded them
  with `minikube image load` instead of pulling `ghcr.io/YOUR_ORG/...:latest`.
- Some long outputs are filtered with `tail`/`grep` so the window stays readable (12, 17,
  44). Screenshots 01, 04 and 11 only show the last ~90 lines of a long run.

---

## §5 Docker Compose

```bash
docker compose up --build
```

![compose up, first run](screenshots/01-compose-up-build_24BCS10244.png)
![backend exited](screenshots/02-backend-raced-postgres_24BCS10244.png)

### Problem found: the backend died on the first `docker compose up`

`backend-1 exited with code 1`, and `docker compose ps -a` shows it as `Exited (1)` while
Postgres and the frontend are up. The backend log ends with
`connection to server at "172.19.0.2", port 5432 failed: Connection refused`. The Postgres
log shows the cause: it was still running `initdb` on the fresh volume, and only printed
`database system is ready to accept connections` afterwards.

**Root cause.** `depends_on: [postgres]` only waits for the Postgres *container* to start,
not for the database to accept connections. The backend's CMD runs `alembic upgrade head`
straight away, so it fails and exits, and Compose has no restart policy.

**Fix.** One line on the `backend` service, `restart: on-failure`, so it retries once
Postgres is ready. I reset the stack with `down -v` so the second run is a real first start
again.

![fix](screenshots/03-compose-restart-fix_24BCS10244.png)
![compose up after fix](screenshots/04-compose-up-after-fix_24BCS10244.png)

The race happened again (`backend-1 exited with code 1 (restarting)`), but this time Docker
restarted it. Alembic then ran `Running upgrade -> 0001_create_tasks` and Uvicorn started.

**Open the app**: the README's "browse" steps, done with curl:

```bash
docker compose ps
curl -s http://localhost:3000
curl -s http://localhost:3000/api/tasks
curl -s http://localhost:8000/docs
curl -s http://localhost:8000/health
curl -s http://localhost:8000/metrics
```

![frontend](screenshots/05-curl-frontend_24BCS10244.png)
![backend docs health metrics](screenshots/06-curl-backend-docs-health-metrics_24BCS10244.png)

Port 3000 serves the built React app (`<title>TaskBoard</title>`), and `/api/tasks` on port
3000 goes through nginx to the backend (`[]`). On 8000, `/docs` is the Swagger UI,
`/health` returns `{"status":"UP"}` and `/metrics` is in Prometheus text format.

```bash
docker compose down
docker compose down -v
```

![down](screenshots/07-compose-down_24BCS10244.png)

`down` removes the containers and the network but keeps the `postgres-data` volume. `down -v`
removes the volume as well.

## §6 Run the backend directly

```bash
cd backend
python -m venv .venv                       # as written: no `python` on macOS
python3 -m venv $S/venvs/session21         # venv kept outside the repo
source $S/venvs/session21/bin/activate
pip install -r requirements.txt
```

![venv](screenshots/08-venv_24BCS10244.png)
![pip install fails](screenshots/09-pip-install_24BCS10244.png)

### Problem found: `pip install` fails on Python 3.14

`No matching distribution found for psycopg-binary==3.2.3`. pip lists the versions that
*are* available for my Python: 3.2.10 and newer.

**Root cause.** `psycopg-binary` only ships pre-built wheels, and 3.2.3 is older than Python
3.14, so it has no `cp314` wheel. The README says "Python 3.12+", and 3.14 meets that.

**Fix.** Pin `psycopg[binary]==3.2.10`, the first version with 3.14 wheels. It still
supports 3.12, so the Docker image and CI (both on 3.12) are not affected.

![fix](screenshots/10-psycopg-pin-fix_24BCS10244.png)
![pip install ok](screenshots/11-pip-install-fixed_24BCS10244.png)

### Problem found: nothing is listening on 5432

```bash
export DATABASE_URL='postgresql+psycopg://taskboard:taskboard@localhost:5432/taskboard'
alembic upgrade head
```

![alembic fails](screenshots/12-alembic-no-postgres_24BCS10244.png)

The README lists "PostgreSQL" as a requirement but doesn't say how to start it, and I had just
run `docker compose down -v`. `lsof` shows nothing on 5432, and Alembic gets
`Connection refused`. Fix: start only the Compose Postgres service and wait for it.

```bash
docker compose up -d postgres
alembic upgrade head
```

![start postgres](screenshots/13-start-postgres_24BCS10244.png)
![alembic ok](screenshots/14-alembic-upgrade_24BCS10244.png)

`Running upgrade -> 0001_create_tasks`, and `\dt` shows the `tasks` table and Alembic's own
`alembic_version` table.

```bash
uvicorn app.main:app --reload --port 8000
curl http://localhost:8000/health
curl http://localhost:8000/api/tasks
```

![uvicorn](screenshots/15-uvicorn_24BCS10244.png)
![curl](screenshots/16-curl-backend-direct_24BCS10244.png)

## §7 Pytest

```bash
cd backend
pytest -q
```

![pytest fails](screenshots/17-pytest-fails_24BCS10244.png)

### Problem found: `test_create_task_validation` fails on a clean checkout

`1 failed, 2 passed`, with `sqlite3.OperationalError: no such table: tasks`. I filtered the
output with `grep`; the full run only adds deprecation warnings.

**Root cause.** The test points `DATABASE_URL` at a new SQLite file. The app creates its
tables in `@app.on_event("startup")`, but `TestClient` only runs startup events when it is
used as a context manager (`with TestClient(app) as client`). The tests use a plain
module-level `client`, so `create_all` never runs. `/health` and `/` pass because they don't
touch the database.

**Fix.** Add a module-scoped autouse fixture that enters `with client:` for the tests.

![pytest passes](screenshots/18-pytest-fixed_24BCS10244.png)

`3 passed`. The 31 warnings are deprecations (`on_event`, and asyncio functions that
Python 3.14 has deprecated), not failures.

## §8 Git

I didn't make a git repo inside my homework repo. I ran the README's commands in a scratch
copy of this folder, outside the repo, with my GitHub identity set only for that repo.

```bash
git init
git config user.name abdur-code
git config user.email abdurrahmanim2422@gmail.com
git add .
git commit -m "initial TaskBoard application"
git branch -M main
```

![git init](screenshots/19-git-init_24BCS10244.png)
![git commit](screenshots/20-git-commit_24BCS10244.png)

`git remote add origin …` and `git push -u origin main` need a GitHub repository, so they are
listed under Pending.

## §9–10 Docker images

```bash
docker build -t taskboard-backend:local ./backend
```

![backend build](screenshots/21-docker-build-backend_24BCS10244.png)

```bash
docker run --rm -p 8000:8000 \
  -e DATABASE_URL='postgresql+psycopg://taskboard:taskboard@host.docker.internal:5432/taskboard' \
  taskboard-backend:local
```

![docker run](screenshots/22-docker-run-backend_24BCS10244.png)
![curl](screenshots/23-curl-docker-run_24BCS10244.png)
![stop](screenshots/24-docker-stop-backend_24BCS10244.png)

The container reaches the Compose Postgres on my Mac through `host.docker.internal`. Alembic
had nothing to do because §6 had already migrated the database. Interrupting `docker run`
in its window didn't stop the container, so I stopped it with `docker stop` from a second
terminal.

```bash
docker build -t taskboard-frontend:local ./frontend
```

![frontend build](screenshots/25-docker-build-frontend_24BCS10244.png)

Every step is `CACHED` because `docker compose up --build` in §5 had already built the same
Dockerfile and context. The multi-stage build leaves Node out of the final image: 76 MB,
against 325 MB for the Python backend.

## §11–12 GitHub Actions and Trivy

These only run on GitHub (`.github/workflows/ci-cd.yml` triggers on a push to `main`), so I
didn't run anything locally. See Pending.

## §13 Terraform

The Terraform part ran on my own AWS account and is written up separately in
[terraform/README.md](terraform/README.md): init failing on the lecture's one-line HCL,
the fix, a 49-resource plan, an apply that hung because my Free-plan account can't launch
`t3.medium`, the fix to `t3.small`, two Ready EKS nodes, `destroy`, and a final check that
nothing was left in the account.

## §14–15 Namespace and Helm

```bash
kubectl apply -f k8s/namespace.yaml
helm upgrade --install taskboard ./helm/taskboard --namespace taskboard --create-namespace
```

![helm fails](screenshots/26-namespace-helm-install_24BCS10244.png)

### Problem found: `no matches for kind "ServiceMonitor"`

**Root cause.** `values.yaml` has `monitoring.serviceMonitor.enabled: true`, and a
ServiceMonitor is a custom resource from the Prometheus Operator. My cluster doesn't have
that CRD, so Helm refuses the whole release and nothing is installed.

**Fix.** Turn that one template off for this install. No Prometheus is installed, because
the README has no monitoring commands to run.

```bash
helm upgrade --install taskboard ./helm/taskboard --namespace taskboard --create-namespace \
  --set monitoring.serviceMonitor.enabled=false
```

![helm ok](screenshots/27-helm-install-no-servicemonitor_24BCS10244.png)
![invalid image](screenshots/28-pods-invalid-image_24BCS10244.png)

### Problem found: `InvalidImageName`

Postgres is `Running`, but the four app Pods are stuck. The image is the placeholder
`ghcr.io/YOUR_ORG/taskboard-backend:latest`, and the event says
`repository name (YOUR_ORG/taskboard-backend) must be lowercase`. Even with a real org name
it would only exist after the CI pipeline had pushed it.

**Fix.** Use the images I built in §9–10. `minikube image load` copies them into the
cluster's container runtime. Their tag is `local`, not `latest`, so the default
`imagePullPolicy` is `IfNotPresent` and the kubelet uses the loaded copy instead of trying
a registry.

```bash
minikube image load taskboard-backend:local
minikube image load taskboard-frontend:local
helm upgrade --install taskboard ./helm/taskboard --namespace taskboard --create-namespace \
  --set monitoring.serviceMonitor.enabled=false \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local
```

![image load](screenshots/29-minikube-image-load_24BCS10244.png)
![upgrade](screenshots/30-helm-upgrade-local-images_24BCS10244.png)
![frontend crash](screenshots/31-frontend-crashloop_24BCS10244.png)

### Problem found: frontend in `CrashLoopBackOff`

Now the backend is `Running`, but nginx in the frontend exits with
`host not found in upstream "backend" in /etc/nginx/conf.d/default.conf:13`.

**Root cause.** `frontend/nginx.conf` proxies `/api/` to `http://backend:8000`. That works in
Compose, where the service is called `backend`. In the chart the backend Service is called
`{{ .Release.Name }}-taskboard-backend` (= `taskboard-taskboard-backend`). nginx resolves
upstream names when it starts, so a missing name stops it from starting at all.

**Fix.** Rename the backend Service in the chart to `backend`. The Compose name now works in
Kubernetes too, and the frontend image doesn't need rebuilding. I ran the same `helm upgrade`
again (revision 3).

![service fix](screenshots/32-backend-service-fix_24BCS10244.png)

All Pods are `Running`, `service/backend` exists, and the frontend logs show the kubelet's
probes getting `200`. (A screen-capture problem on the Mac ruined the window with the
upgrade itself, so this screenshot shows `helm history` and the resulting state instead.)

## §20 HPA (while it was enabled)

```bash
kubectl get hpa -n taskboard
```

![hpa](screenshots/33-get-hpa_24BCS10244.png)

`cpu: 2%/60%`, min 2, max 6, 2 replicas. metrics-server provides the CPU numbers, and the
percentage is measured against the 100m CPU request in `values.yaml`.

## §19 Ingress with `values-dev.yaml`

```bash
helm upgrade --install taskboard ./helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml
```

![values-dev as written](screenshots/34-helm-values-dev-as-written_24BCS10244.png)

As written this fails with the same ServiceMonitor error. A `helm upgrade` without
`--reuse-values` starts again from `values.yaml`, so my `--set` flags from §15 were lost.
I re-ran it with the same flags:

```bash
helm upgrade --install taskboard ./helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml \
  --set monitoring.serviceMonitor.enabled=false \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local
kubectl get ingress -n taskboard
kubectl get hpa -n taskboard
```

![values-dev](screenshots/35-helm-values-dev_24BCS10244.png)

The Ingress `taskboard` (class `nginx`, host `taskboard.local`) now exists. The HPA is gone
because `values-dev.yaml` sets `hpa.enabled: false`. I come back to this in §20 below.

**Reach the ingress without `/etc/hosts`:** port-forward the minikube ingress controller and
send the host name as a header.

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 18210:80
curl -s  -H "Host: taskboard.local" http://localhost:18210/
curl -i  -H "Host: taskboard.local" http://localhost:18210/api/tasks
```

![port-forward](screenshots/36-port-forward-ingress_24BCS10244.png)
![api 503](screenshots/37-ingress-api-503_24BCS10244.png)

### Problem found: `/api` returns 503 through the Ingress

`/` returns the React app, but `/api/tasks` gets `503 Service Temporarily Unavailable`.
`kubectl describe ingress` shows the cause:
`/api taskboard-backend:8080 (<error: services "taskboard-backend" not found>)`.

**Root cause.** `templates/ingress.yaml` names a Service and port that don't exist. The
chart never created `taskboard-backend` (now it is `backend`), and the backend listens on
**8000**, not 8080.

**Fix.** Point `/api` at `backend:8000`, then run the same upgrade again (revision 5).

![ingress fix](screenshots/38-ingress-fix_24BCS10244.png)
![ingress works](screenshots/39-ingress-verify_24BCS10244.png)

Both paths now have endpoints. Through the Ingress I loaded the UI, created a task with
`POST /api/tasks` (the README's "create a task"), listed it, and `/api/tasks/stats` counts it.
This goes Ingress → backend → PostgreSQL in the cluster.

## §20 HPA (back on)

`values-dev.yaml` turns the HPA off, so `kubectl get hpa` printed "No resources found"
(screenshot 35). To have an HPA again for §20 and the Part O check, I added one flag to the
dev upgrade:

```bash
helm upgrade --install taskboard ./helm/taskboard -n taskboard -f helm/taskboard/values-dev.yaml \
  --set monitoring.serviceMonitor.enabled=false \
  --set backend.image=taskboard-backend --set backend.tag=local \
  --set frontend.image=taskboard-frontend --set frontend.tag=local \
  --set hpa.enabled=true
kubectl get hpa -n taskboard
```

![hpa back](screenshots/40-hpa-reenabled_24BCS10244.png)

Right after creation the target is `<unknown>` because metrics-server hadn't scraped yet.
The HPA then scaled the backend from 1 (values-dev `replicaCount`) up to its `minReplicas` of
2 (screenshot 53).

## §21–22 Monitoring

The README has no commands for Prometheus/Grafana, so there was nothing to run. The chart's
ServiceMonitor stayed disabled (see §15), and `/metrics` works (screenshot 06).

## §23 Troubleshooting: broken image

```bash
kubectl apply -f troubleshooting/broken-image.yaml
```

![apply](screenshots/41-broken-image-apply_24BCS10244.png)

**As written.** The README's next commands have no `-n taskboard`. I ran them in a terminal
with the normal kubeconfig, where the default namespace is `default`:

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl get events --sort-by=.lastTimestamp
```

![as written](screenshots/42-broken-image-as-written_24BCS10244.png)

`No resources found in default namespace`, `NotFound`, and an unrelated event. The manifest
puts the Deployment in `taskboard`, so you have to look there.

**Identify** (with the namespace):

```bash
kubectl get pods -n taskboard
kubectl describe pod <pod-name> -n taskboard
kubectl get events -n taskboard --sort-by=.lastTimestamp
```

![investigate](screenshots/43-broken-image-investigate_24BCS10244.png)
![events](screenshots/44-broken-image-events_24BCS10244.png)

**Root cause.** The Pod is `ErrImagePull` → `ImagePullBackOff`. `describe` shows the image
`ghcr.io/example/taskboard-backend:does-not-exist`, and the kubelet event says ghcr.io
answered `403 Forbidden`: the image doesn't exist, or isn't public.

**Fix 1: correct image.** I set the image to `taskboard-backend:local` and applied it.

![fix image](screenshots/45-broken-image-fix-image_24BCS10244.png)

The image problem is gone, because the container now starts. But it immediately exits
(`Error`, restarts) with `connection to server at "127.0.0.1", port 5432 failed`: this
Deployment gives the backend no `DATABASE_URL`, so it falls back to `localhost`. (The
`kubectl logs` command shows up once before the `get pods` output because it was typed while
`sleep 25` was still running; the output is not affected.)

**Fix 2: give it the database URL**, the same value the Helm backend uses, then verify:

```bash
kubectl apply -f troubleshooting/broken-image.yaml
kubectl rollout status deploy/taskboard-broken-image -n taskboard
kubectl get pods -n taskboard -l app=broken-image
kubectl logs -n taskboard deploy/taskboard-broken-image --tail=4
```

![fixed](screenshots/46-broken-image-fixed_24BCS10244.png)

`1/1 Running` and `Uvicorn running on http://0.0.0.0:8000`.

## §24 Troubleshooting: broken Service

```bash
kubectl apply -f troubleshooting/broken-service.yaml
kubectl get svc
kubectl get endpoints
kubectl get pods --show-labels
```

![apply](screenshots/47-broken-service-apply_24BCS10244.png)
![as written](screenshots/48-broken-service-as-written_24BCS10244.png)

As written (namespace `default`) these only show the built-in `kubernetes` Service. With the
namespace:

![investigate](screenshots/49-broken-service-investigate_24BCS10244.png)

**Identify.** `broken-service` exists but its endpoints are `<none>`.

**Root cause.** Its selector is `app=label-that-does-not-exist`, and no Pod has that label
(see `--show-labels`). The `targetPort` is also 8080, while the backend endpoints show the
app on port 8000.

**Fix.** Selector `app: taskboard-backend` and `targetPort: 8000`. The Service keeps port
8080 for its clients.

![fixed](screenshots/50-broken-service-fixed_24BCS10244.png)

**Verify.** The endpoints are the two backend Pod IPs on `:8000`. To check that traffic
flows, I sent requests through the Service:

```bash
kubectl port-forward -n taskboard svc/broken-service 18211:8080
curl -s http://localhost:18211/health
curl -s http://localhost:18211/api/tasks
```

![port-forward](screenshots/51-port-forward-broken-service_24BCS10244.png)
![traffic](screenshots/52-broken-service-traffic_24BCS10244.png)

`{"status":"UP"}`, and the task I created through the Ingress comes back, served by the same
backend Pods.

## Part O: final checks

```bash
kubectl get pods -n taskboard
kubectl get svc -n taskboard
helm list -n taskboard
kubectl get hpa -n taskboard
```

![final](screenshots/53-part-o-final-checks_24BCS10244.png)

Every Pod is `Running`, including the fixed troubleshooting Deployment. The release is at
revision 6, and the HPA reads `cpu: 2%/60%` with 2 replicas.

## Cleanup

```bash
helm uninstall taskboard -n taskboard
kubectl delete namespace taskboard
docker compose down -v
minikube image rm taskboard-backend:local taskboard-frontend:local
docker rmi taskboard-backend:local taskboard-frontend:local \
  20-final-devops-project-backend 20-final-devops-project-frontend
rm -rf $S/venvs/session21
```

![k8s cleanup](screenshots/54-cleanup-kubernetes_24BCS10244.png)
![docker cleanup](screenshots/55-cleanup-docker-venv_24BCS10244.png)

The Postgres PV was dynamically provisioned (reclaim policy `Delete`), so it went away with
the namespace's PVC.

---

## Pending: needs the student

1. **§8 push.** Create an empty GitHub repository, e.g. `abdur-code/taskboard`. The workflow
   must sit at the repository root (`.github/workflows/`), so push this folder as its own
   repo, not as part of the homework repo. From a copy of this folder:
   ```bash
   git init
   git add .
   git commit -m "initial TaskBoard application"
   git branch -M main
   git remote add origin https://github.com/abdur-code/taskboard.git
   git push -u origin main
   ```
   Before `git add`, check that `terraform/` state and plan files are not staged.
2. **§11–12 GitHub Actions, Trivy and GHCR** run on that push: pytest, the frontend build, both
   image builds, the Trivy scans, and the push to `ghcr.io/abdur-code/…`. The `deploy` job also
   needs a `KUBE_CONFIG_DATA` repository secret and a cluster it can reach.

## What I understood

- **Each layer can only rely on what the layer below guarantees.** `depends_on` guarantees a
  started container, not a ready database. Kubernetes is the same: a readiness probe and
  restarts are what make "wait for Postgres" actually work.
- **Names are the glue, and they break quietly.** The frontend, the Ingress and the broken
  Service all failed for the same reason: something referred to a Service name, port or
  label that didn't match. `describe`, `get endpoints` and `--show-labels` found every one.
- **Read the error before fixing the obvious thing.** In the broken-image lab, fixing the
  image only revealed the next problem (no `DATABASE_URL`). Checking the result after every
  fix is what found it.
- **Helm values don't stack between upgrades.** Each `helm upgrade` starts from `values.yaml`
  plus whatever you pass this time, so the dev overlay quietly turned the HPA off and dropped
  my image overrides.
- **"Works on my machine" is not a test result.** The pytest failure only shows up on a
  clean checkout with no `test.db`, and an exact pin from last year had no wheel for this
  year's Python. CI on a fresh runner is what catches both.
