# Complete CI/CD and DevSecOps Pipeline

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Session 17. I took the lecture's Flask demo app (`hey-cicd`) through a complete
CI/CD + DevSecOps flow:

```text
Code → Build → Unit Test → SAST → SCA → Secret Scan → Docker Build
     → Container Image Scan → Security Gate → Push Image → Deploy to Kubernetes
```

Every stage is run by hand first (sections 1 to 7), then all of them together:

- `devsecops-pipeline.sh` runs the whole flow on my Mac in that order, stops at the
  first failing gate, and deploys to minikube (section 8).
- A corrected GitHub Actions workflow runs the same flow in CI and pushes to GHCR
  (section 9). I ran it locally with `act`; the real GitHub run is listed under
  "Pending" below.

The scanners found real problems in the lecture material, and fixing them is most of
this homework:

- the app shipped with the Werkzeug debugger on
- the image had 44 HIGH CVEs and the Trivy step could never fail
- the Kubernetes manifest couldn't pull its image
- `.dockerignore` had an invisible typo in its name
- the workflow scanned a different image from the one it pushed

Every screenshot is my own terminal.

## Homework checklist → where it is

| Homework item | Where | Tool |
|---|---|---|
| Application build | [01](01-build-and-unit-test/), stage 1 of [08](08-local-pipeline/) | venv + pip, import check |
| Unit testing | [01](01-build-and-unit-test/), [02](02-sast/) (new test) | pytest + pytest-cov, coverage gate 60% |
| SAST | [02](02-sast/) | bandit (blocking), CodeQL (Security tab, in CI) |
| SCA | [03](03-sca/) | pip-audit |
| Secret scanning | [04](04-secret-scanning/) | gitleaks + custom rule |
| Docker image build | [05](05-docker-build/) | Docker / BuildKit |
| Container image scanning | [06](06-image-scan-and-gate/) | Trivy |
| Security gates | [06](06-image-scan-and-gate/), [08](08-local-pipeline/) (failing runs) | exit codes, `needs:` |
| Container registry | [07](07-kubernetes-deploy/) (`minikube image load`), [09](09-github-actions/) (GHCR) | GHCR with `GITHUB_TOKEN` |
| Kubernetes deployment | [07](07-kubernetes-deploy/), stage 10 of [08](08-local-pipeline/) | kubectl, minikube; kind in CI |
| Successful pipeline output | [08](08-local-pipeline/) (full local run), [09](09-github-actions/) (act run) | |
| GitHub Actions workflow | [`hey-cicd/.github/workflows/devsecops.yml`](hey-cicd/.github/workflows/devsecops.yml), [09](09-github-actions/) | |
| Security tool configuration | `.gitleaks.toml`, `.github/scripts/install-scanner.sh`, gate thresholds in the workflow and script, hardened `Dockerfile` and `k8s/deployment.yaml` | |
| Kubernetes manifests | [`hey-cicd/k8s/`](hey-cicd/k8s/) | |

## Folder structure

```text
16-devsecops/
├── README.md                     this file
├── devsecops-pipeline.sh         the whole flow, locally, fail-fast (section 8)
├── hey-cicd/                     the application repository (all deliverables)
│   ├── app/                      app.py, templates/, static/
│   ├── tests/test_app.py         9 unit tests
│   ├── k8s/                      deployment.yaml, service.yaml
│   ├── .github/workflows/        devsecops.yml (corrected, 10 stages)
│   ├── .github/scripts/          install-scanner.sh (pinned + checksum-verified gitleaks/Trivy)
│   ├── Dockerfile  .dockerignore  .gitleaks.toml  .gitignore
│   ├── requirements.txt  requirements-dev.txt  pytest.ini
│   └── README.md
├── 01-build-and-unit-test/
├── 02-sast/
├── 03-sca/
├── 04-secret-scanning/
├── 05-docker-build/
├── 06-image-scan-and-gate/
├── 07-kubernetes-deploy/
├── 08-local-pipeline/
└── 09-github-actions/
```

Each numbered folder has a README with the commands, screenshots (in `screenshots/`)
and what the output shows. 67 screenshots in total.

## Problems found in the lecture material

| # | Problem | Root cause | Fix | Section |
|---|---|---|---|---|
| 1 | Container runs with the Werkzeug debugger on (bandit B201 HIGH, B104 MEDIUM) | `app.run(host="0.0.0.0", port=5001, debug=True)` hard-coded | `HOST`/`PORT`/`FLASK_DEBUG` from env, safe defaults | [02](02-sast/) |
| 2 | `POST /api/calculate` with `10 ** 1000` → 500 + debugger page | unhandled `OverflowError` | return 400, new unit test | [02](02-sast/) |
| 3 | `pytest==8.4.2` vulnerable (PYSEC-2026-1845) | outdated pin | `pytest==9.0.3` | [03](03-sca/) |
| 4 | The lecture's own "never do this" secret isn't detected | gitleaks default rules only match known formats / high entropy | custom rule in `.gitleaks.toml` | [04](04-secret-scanning/) |
| 5 | No `.dockerignore`; host `__pycache__` copied into the image | file named `.dockerignore␠␠│` | real `.dockerignore` | [05](05-docker-build/) |
| 6 | `docker stop` → `Exited (137)` after a delay | Python as PID 1 ignores SIGTERM | `STOPSIGNAL SIGINT` | [05](05-docker-build/), [06](06-image-scan-and-gate/) |
| 7 | 44 HIGH CVEs in the image; Trivy step can't fail | `python:3.12-slim` base, pip's vendored libs; no `--exit-code 1` | Alpine base, `apk upgrade`, pip removed, non-root, gate with `--exit-code 1` | [06](06-image-scan-and-gate/) |
| 8 | Pods stuck in `ImagePullBackOff` | `nensiravaliya28/hey-cicd:__IMAGE_TAG__` + `imagePullPolicy: Always` | `hey-cicd:1.0` + `IfNotPresent`, `minikube image load`; probes added | [07](07-kubernetes-deploy/) |
| 9 | Workflow: test/SAST/SCA in parallel, no secret scan, scanned image ≠ pushed image, pushes to instructor's Docker Hub, CodeQL never blocks | workflow design | strict `needs:` chain, gitleaks job, build once + artifact, GHCR with `GITHUB_TOKEN`, bandit as blocking SAST | [09](09-github-actions/) |
| 10 | `03-kubernetes-deployment` notes vs `demo/k8s` disagree | `devsecops-python`/5000/30080 vs `session17-python`/5001/30001 | followed the files I deploy (`session17-python`, 5001) | [07](07-kubernetes-deploy/) |

## Environment notes

- macOS on Apple Silicon, Docker Desktop, minikube v1.39 (docker driver, Kubernetes
  v1.37), Trivy 0.75.0, gitleaks 8.30.1, bandit 1.9.4, pip-audit 2.10.1, act 0.2.89.
  Python 3.14 locally; the image and CI use Python 3.12.
- **Namespace:** everything ran in `devsecops-lab`, set as the default namespace of my
  terminal's kubeconfig, so this session could run side by side with others on the same
  cluster. The namespace was deleted at the end.
- **Ports:** the app listens on 5001 inside containers and Pods, but everything published
  on my Mac is in 18170–18179:

  | Port | Used for | Lecture had |
  |---|---|---|
  | 18170 | `flask run` locally | `python3 app/app.py` on 5001 |
  | 18171 | `kubectl port-forward svc/session17-python 18171:80` | `port-forward … 8080:5000`, `minikube service` |
  | 18172 | debug-mode demo container | – |
  | 18173 | `docker run -p 18173:5001` | `-p 5001:5001` |
  | 18174 | hardened image check | – |
  | 18175 | smoke test inside `devsecops-pipeline.sh` | – |

- `minikube service` / NodePort isn't reachable from macOS with the docker driver, so I
  used `kubectl port-forward` instead.
- `$VENV` in the commands is a virtualenv kept outside the repo (Homebrew Python blocks
  global pip). `$DEMO` is the lecture's `demo/` folder, and `$WORK` is a scratch folder
  outside the repo for throwaway copies (leaked-secret demo, failing-gate runs, the git
  repo for `act`). Nothing in the homework repo was committed by these steps.
- The terminal is zsh, so `${pipestatus[1]}` (the first command's exit code in a pipe)
  appears in a few commands.
- No image was pushed to any registry from my machine. "Push" locally means
  `minikube image load`; the GHCR push is done by the workflow on GitHub.

## Pending: needs the student

These need my GitHub account, so they weren't run here. Everything they need is in
`hey-cicd/`. Details and the expected result for each step are in
[09-github-actions](09-github-actions/README.md#pending-run-it-on-github).

1. Push `hey-cicd/` as its own repository on the personal account `abdur-code`, so
   `.github/workflows/devsecops.yml` is at the repo root and Actions picks it up.
2. Watch the Actions run: 10 jobs plus CodeQL. Screenshot the run graph.
3. Check **Security → Code scanning** for the CodeQL results (CodeQL can't run under `act`).
4. Check **Packages** for `ghcr.io/abdur-code/hey-cicd` with the commit-SHA and `latest` tags.
5. Screenshot the `10. Deploy to Kubernetes` job log (rollout + `/health` from the kind cluster).

No repository secrets are needed: GHCR login and the cluster's image pull use the
built-in `GITHUB_TOKEN`.
