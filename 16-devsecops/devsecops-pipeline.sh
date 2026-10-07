#!/usr/bin/env bash
# devsecops-pipeline.sh: run the homework's CI/CD + DevSecOps flow locally, in order,
# and stop at the first stage that fails.
#
#   Code -> Build -> Unit Test -> SAST -> SCA -> Secret Scan -> Docker Build
#        -> Container Image Scan -> Security Gate -> Push Image -> Deploy to Kubernetes
#
# Usage:   ./devsecops-pipeline.sh [project-dir]          (default: ./hey-cicd)
# Env:     VENV        Python venv for the app + tools  (default: <project>/.venv)
#          TAG         image tag                        (default: hash of the app source)
#          NS          Kubernetes namespace             (default: devsecops-lab)
#          SMOKE_PORT  local port for the smoke test    (default: 18175)
#
# Gate policy (same as .github/workflows/devsecops.yml):
#   unit tests   any failing test, or coverage below 60%
#   SAST         any bandit finding of MEDIUM or HIGH severity
#   SCA          any known vulnerability in requirements*.txt (pip-audit)
#   secrets      any gitleaks finding (built-in rules + .gitleaks.toml)
#   image        any HIGH or CRITICAL vulnerability (trivy --exit-code 1)
#
# "Push Image" loads the image into minikube's container runtime with
# `minikube image load`, the local stand-in for a registry. The GitHub Actions
# workflow pushes to GHCR instead.

set -Eeuo pipefail

PROJECT="$(cd "${1:-$(dirname "$0")/hey-cicd}" && pwd)"
VENV="${VENV:-$PROJECT/.venv}"
NS="${NS:-devsecops-lab}"
SMOKE_PORT="${SMOKE_PORT:-18175}"
DEPLOYMENT=session17-python
TOTAL=10

cd "$PROJECT"
export PYTHONDONTWRITEBYTECODE=1          # keep __pycache__ out of the project
REPORTS="$(mktemp -d -t devsecops-reports)"
export COVERAGE_FILE="$REPORTS/.coverage"

# The tag is a hash of everything that goes into the image, so the same code
# always gives the same tag and a code change always gives a new one.
TAG="${TAG:-$(find app requirements.txt Dockerfile .dockerignore -type f ! -name '*.pyc' -print0 \
  | LC_ALL=C sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -c1-10)}"
IMAGE="hey-cicd:$TAG"

bold=$'\033[1m'; green=$'\033[32m'; red=$'\033[31m'; reset=$'\033[0m'
STAGE_NO=0; STAGE_NAME="Code"; STAGE_T0=$SECONDS; PF_PID=""

stage() {
  STAGE_NO=$((STAGE_NO + 1)); STAGE_NAME="$1"; STAGE_T0=$SECONDS
  printf '\n%s==> [%d/%d] %s%s\n' "$bold" "$STAGE_NO" "$TOTAL" "$1" "$reset"
}
pass() { printf '%s    PASS%s  %s (%ss)\n' "$green" "$reset" "$STAGE_NAME" "$((SECONDS - STAGE_T0))"; }
on_fail() {
  printf '\n%sFAILED at stage %d/%d: %s. Pipeline stopped, later stages did not run.%s\n' \
    "$red" "$STAGE_NO" "$TOTAL" "$STAGE_NAME" "$reset"
}
cleanup() { [ -n "$PF_PID" ] && kill "$PF_PID" 2>/dev/null; true; }
trap on_fail ERR
trap cleanup EXIT

for tool in docker trivy gitleaks minikube kubectl jq curl shasum; do
  command -v "$tool" >/dev/null || { echo "missing tool: $tool"; exit 1; }
done

printf '%s==> Code%s  %s\n    image %s, namespace %s, reports in %s\n' \
  "$bold" "$reset" "$PROJECT" "$IMAGE" "$NS" "$REPORTS"

# ---------------------------------------------------------------- 1. Build
stage "Build (venv, dependencies, import check)"
[ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
PY="$VENV/bin/python"
"$PY" -m pip install -q --disable-pip-version-check -r requirements-dev.txt bandit==1.9.4 pip-audit==2.10.1
"$PY" -c 'import sys; from app.app import app; print(f"    Python {sys.version.split()[0]}, Flask app {app.name!r} imports, {len(list(app.url_map.iter_rules()))} routes")'
pass

# ---------------------------------------------------------------- 2. Unit tests
stage "Unit Test (pytest, coverage >= 60%)"
"$PY" -m pytest -q -p no:cacheprovider --cov=app --cov-report=term --cov-fail-under=60 | sed 's/^/    /'
pass

# ---------------------------------------------------------------- 3. SAST
stage "SAST (bandit, block on MEDIUM/HIGH)"
"$PY" -m bandit -q -r app -f json -o "$REPORTS/bandit.json" --exit-zero
jq -r '.metrics._totals | "    findings: HIGH=\(."SEVERITY.HIGH") MEDIUM=\(."SEVERITY.MEDIUM") LOW=\(."SEVERITY.LOW") (LOW is reported, not blocking)"' \
  "$REPORTS/bandit.json"
"$PY" -m bandit -q -r app --severity-level medium -f custom \
  --msg-template '    {relpath}:{line} {test_id} [{severity}] {msg}'
pass

# ---------------------------------------------------------------- 4. SCA
stage "SCA (pip-audit on requirements.txt + requirements-dev.txt)"
"$PY" -m pip_audit --progress-spinner off -r requirements.txt -r requirements-dev.txt 2>&1 | sed 's/^/    /'
pass

# ---------------------------------------------------------------- 5. Secret scan
stage "Secret Scan (gitleaks, built-in rules + .gitleaks.toml)"
gitleaks dir . --no-banner --redact 2>&1 | sed 's/^/    /'
if [ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$PROJECT" ]; then
  gitleaks git . --no-banner --redact 2>&1 | sed 's/^/    /'      # history, when this is a repo
fi
pass

# ---------------------------------------------------------------- 6. Docker build
stage "Docker Build ($IMAGE)"
docker build -q -t "$IMAGE" . | sed 's/^/    /'
pass

# ---------------------------------------------------------------- 7. Image scan
stage "Container Image Scan (trivy, full report)"
trivy image -q --format json -o "$REPORTS/trivy-image.json" "$IMAGE"
jq -r '[.Results[]?.Vulnerabilities[]?.Severity] as $s
       | "    vulnerabilities: " + (["CRITICAL","HIGH","MEDIUM","LOW","UNKNOWN"]
         | map(. as $sev | "\($sev)=\([$s[] | select(. == $sev)] | length)") | join(" "))' \
  "$REPORTS/trivy-image.json"
echo "    report: $REPORTS/trivy-image.json"
pass

# ---------------------------------------------------------------- 8. Security gate
stage "Security Gate (trivy --severity HIGH,CRITICAL --exit-code 1)"
if trivy image -q --severity HIGH,CRITICAL --exit-code 1 \
     --format json -o "$REPORTS/trivy-gate.json" "$IMAGE"; then
  echo "    0 HIGH/CRITICAL vulnerabilities: the image may be published"
else
  jq -r '.Results[]?.Vulnerabilities[]? | "    \(.Severity)  \(.PkgName) \(.InstalledVersion)  \(.VulnerabilityID)  fixed in: \(.FixedVersion // "no fix yet")"' \
    "$REPORTS/trivy-gate.json" | sort -u | head -n 12
  echo "    $(jq '[.Results[]?.Vulnerabilities[]?] | length' "$REPORTS/trivy-gate.json") HIGH/CRITICAL findings: image is NOT pushed or deployed"
  false
fi
pass

# ---------------------------------------------------------------- 9. Push
stage "Push Image (minikube image load = local registry stand-in)"
minikube image load "$IMAGE"
minikube image ls | grep -F "$IMAGE" | sed 's/^/    /'
pass

# ---------------------------------------------------------------- 10. Deploy
stage "Deploy to Kubernetes (namespace $NS)"
kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"
sed "s|image: hey-cicd:.*|image: $IMAGE|" k8s/deployment.yaml | kubectl -n "$NS" apply -f - | sed 's/^/    /'
kubectl -n "$NS" apply -f k8s/service.yaml | sed 's/^/    /'
kubectl -n "$NS" rollout status "deployment/$DEPLOYMENT" --timeout=180s | sed 's/^/    /'
kubectl -n "$NS" get pods -l app="$DEPLOYMENT" -o json | jq -r '
  .items[] | select(.metadata.deletionTimestamp == null)      # skip old pods still terminating
  | "    pod \(.metadata.name)  image \(.spec.containers[0].image)  ready \(.status.containerStatuses[0].ready)"'
kubectl -n "$NS" port-forward "svc/$DEPLOYMENT" "$SMOKE_PORT:80" >/dev/null 2>&1 &
PF_PID=$!
ok=""
for _ in $(seq 1 30); do
  if body="$(curl -fsS "http://127.0.0.1:$SMOKE_PORT/health" 2>/dev/null)"; then ok=1; break; fi
  sleep 0.5
done
[ -n "$ok" ] || { echo "    smoke test: /health did not answer"; false; }
echo "    smoke test GET /health -> $body"
pass

printf '\n%sPipeline succeeded:%s %s passed every gate and is running in namespace %s.\n' \
  "$green" "$reset" "$IMAGE" "$NS"
