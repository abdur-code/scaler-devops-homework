# hey-cicd: DevSecOps pipeline demo

A small Flask "DevSecOps Dashboard" (JSON API + web page) with a CI/CD pipeline that
builds, tests and security-scans it, publishes the image to GHCR and deploys it to
Kubernetes. Homework for Scaler DevOps session 17, by Abdur Rahman Ibne Munir
(24BCS10244).

## Pipeline

`.github/workflows/devsecops.yml`, one job per stage, chained with `needs:`:

```text
1 Build → 2 Unit Tests → 3 SAST (bandit; CodeQL to the Security tab) → 4 SCA (pip-audit)
→ 5 Secret Scan (gitleaks) → 6 Docker Build → 7 Image Scan (Trivy)
→ 8 Security Gate (Trivy HIGH/CRITICAL, --exit-code 1) → 9 Push to GHCR → 10 Deploy (kind)
```

Push and deploy only run on a push to `main`. Pull requests stop after the gate.

| Gate | Fails on |
|---|---|
| Unit tests | any failure, coverage < 60% |
| SAST | bandit finding of MEDIUM or HIGH severity |
| SCA | any known vulnerability in `requirements*.txt` |
| Secrets | any gitleaks finding (working tree and full history) |
| Image | any HIGH or CRITICAL vulnerability |

## Security tool configuration

| File | Purpose |
|---|---|
| `.gitleaks.toml` | default gitleaks rules + a rule for hard-coded credential assignments |
| `.github/scripts/install-scanner.sh` | pinned, SHA-256-verified gitleaks and Trivy binaries for CI |
| `Dockerfile` | digest-pinned Alpine base, pip removed after install, non-root UID 10001 |
| `k8s/deployment.yaml` | probes, `runAsNonRoot`, read-only root FS, all capabilities dropped |
| `.dockerignore` | keeps caches, tests and CI files out of the build context |

## Run it

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest --cov=app                      # tests
PORT=5001 python app/app.py                     # http://127.0.0.1:5001 (debug off)

docker build -t hey-cicd:local .
docker run -p 5001:5001 hey-cicd:local          # HOST=0.0.0.0 is set in the image
```

Environment variables: `HOST` (default `127.0.0.1`), `PORT` (default `5001`),
`FLASK_DEBUG=1` to turn on the debugger (never in production).

## API

| Method | Route | |
|---|---|---|
| GET | `/` | dashboard |
| GET | `/health` | health check (used by the probes) |
| GET | `/api/status` | version, uptime, Python version |
| GET | `/api/greet/<name>` | greeting |
| POST | `/api/add` | `{"number1": 10, "number2": 20}` |
| POST | `/api/calculate` | `{"a": 6, "b": 3, "operation": "multiply"}` |
| POST | `/api/pipeline/run` | simulated pipeline run |
