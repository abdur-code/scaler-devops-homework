# Helm: Kubernetes Package Manager

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

Class session 15. Lecture material: [`session-15-helm`](https://github.com/Nency-Ravaliya/devops-heros/tree/main/session-15-helm)
in the course repo. I worked through every lecture topic in order: Helm basics and
repos, chart structure, `Chart.yaml`, `values.yaml`, templates, install/upgrade and
rollback, a full app deployment and the mini project. I added the commands the homework
asks for that the notes skip (`helm status`, `helm get`, `helm repo list/update/remove`,
`helm search repo/hub`) and a separate rollback workflow for Task 2. Every command was
typed in a real terminal on my Mac against a single-node minikube cluster, and every
screenshot is that terminal.

## Homework tasks → where they are

| Task | What was asked | Where |
|---|---|---|
| 1 | Run, understand and document every important Helm command | spread over the lecture folders; see the table below |
| 2 | Rollback workflow: Install → Upgrade → Verify → Upgrade again → Verify → Rollback → Verify | [`task-2-rollback-workflow/`](task-2-rollback-workflow/) |
| 3 | Helm mini project (Notes app chart, dev/prod values, bad upgrade, rollback) | [`mini-project/`](mini-project/) |

Deliverables: the Helm charts, `values.yaml` files and templates are in the folders below
(`demo-chart`, `simple-chart`, `my-app`, `template-demo`, `app-chart`, `guestbook-chart`,
`notes-chart`). Each folder's README has the installation, upgrade and rollback steps with
screenshots.

### Task 1: every Helm command and where it is shown

| Command | What it does | Shown in |
|---|---|---|
| `helm create` | generate a complete chart skeleton | [02](02-helm-charts/README.md) |
| `helm install` | create a release from a chart | [01](01-what-is-helm/README.md) (public chart), [02](02-helm-charts/README.md), [03](03-chart-structure/README.md), [05](05-values-yaml/README.md) (`--set`, `-f`), [07](07-install-upgrade/README.md), [09](09-deploying-application/README.md), [mini project](mini-project/README.md) |
| `helm list` | list releases in the namespace (`-a` includes failed ones) | [01](01-what-is-helm/README.md), [02](02-helm-charts/README.md), [05](05-values-yaml/README.md), [07](07-install-upgrade/README.md), [09](09-deploying-application/README.md) |
| `helm status` *(addition)* | state of a release, current or `--revision N` | [07](07-install-upgrade/README.md) |
| `helm get values / manifest / all` *(addition)* | what a revision was given and what it applied | [07](07-install-upgrade/README.md); also used to debug the [mini project](mini-project/README.md) and in [Task 2](task-2-rollback-workflow/README.md) |
| `helm upgrade` | change a release; `--install`, `--atomic`, `-f`, `--set` | [07](07-install-upgrade/README.md), [08](08-rollback/README.md), [09](09-deploying-application/README.md), [mini project](mini-project/README.md), [Task 2](task-2-rollback-workflow/README.md) |
| `helm history` | revision list of a release | [07](07-install-upgrade/README.md), [08](08-rollback/README.md), [09](09-deploying-application/README.md), [mini project](mini-project/README.md), [Task 2](task-2-rollback-workflow/README.md) |
| `helm rollback` | go back to revision N (or the previous one) | [08](08-rollback/README.md), [09](09-deploying-application/README.md), [mini project](mini-project/README.md), [Task 2](task-2-rollback-workflow/README.md) |
| `helm uninstall` | delete a release and everything it created | every folder; [01](01-what-is-helm/README.md) first |
| `helm repo add / update` | register a chart repo, refresh its index | [01](01-what-is-helm/README.md) |
| `helm repo list / remove` *(addition)* | show and remove registered repos | [01](01-what-is-helm/README.md) |
| `helm search repo` *(addition)* | search the added repos (local index) | [01](01-what-is-helm/README.md) |
| `helm search hub` *(addition)* | search Artifact Hub online | [01](01-what-is-helm/README.md) |
| `helm template`, `helm lint` | render locally / check a chart | [02](02-helm-charts/README.md), [03](03-chart-structure/README.md), [04](04-chart-yaml/README.md), [05](05-values-yaml/README.md), [06](06-templates/README.md), [09](09-deploying-application/README.md), [mini project](mini-project/README.md) |

## Folder structure

```text
14-helm/
├── 01-what-is-helm/             README (install check, bitnami/nginx, repo + search)
├── 02-helm-charts/              demo-chart/ (made with "helm create")
├── 03-chart-structure/          simple-chart/
├── 04-chart-yaml/               my-app/Chart.yaml (moved, see problems), my-app/templates/chart-info.yaml (addition)
├── 05-values-yaml/              my-app/ (helm create chart), values.yaml, values-prod.yaml
├── 06-templates/                template-demo/
├── 07-install-upgrade/          app-chart/  (+ helm status / helm get)
├── 08-rollback/                 README only, uses ../07-install-upgrade/app-chart
├── 09-deploying-application/    guestbook-chart/
├── mini-project/                notes-chart/ (values.yaml, values-prod.yaml)       Task 3
├── task-2-rollback-workflow/    README only, uses ../mini-project/notes-chart      Task 2
└── README.md
```

Each folder has a `screenshots/` directory, and its README walks through them in order
(128 screenshots in total).

## Environment

- macOS (Apple Silicon), Docker Desktop, minikube v1.39 on the docker driver, Kubernetes
  v1.37, one node. Helm **v3.22.0**, installed with Homebrew (`helm@3`).
- **Namespace.** Everything ran in namespace `helm-lab`, created on screen at the start
  ([01](01-what-is-helm/README.md)) and deleted on screen at the end
  ([Task 2](task-2-rollback-workflow/README.md#cleanup-end-of-the-whole-session)). It was
  set as the default namespace of my terminal's kubeconfig so other sessions could use the
  same cluster at the same time. Helm takes the namespace from the kubeconfig too, so every
  release shows `NAMESPACE helm-lab` even though no command passes `-n`.
- **Helm install.** The notes install Helm with `curl … get-helm-3 | bash`. I didn't run
  it, because Helm was already installed through Homebrew and a second, unmanaged copy in
  `/usr/local/bin` would only cause version confusion. `helm version` is shown instead
  ([01](01-what-is-helm/README.md#1-install-helm)).
- **Ports.** NodePorts and LoadBalancer IPs aren't reachable from macOS with the docker
  driver ([shown in 09](09-deploying-application/README.md#5-reach-the-app)), so apps were
  checked with `kubectl port-forward` on my session's ports: 18150 (bitnami nginx), 18151
  (demo-chart; the NOTES.txt says 8080), 18153 (guestbook), 18154 (notes-dev), 18155
  (Task 2).
- **Bitnami.** I ran `bitnami/nginx` as written, expecting it might fail after Bitnami's
  2025 catalogue changes. It installed and served fine (chart 25.2.1, image
  `bitnami/nginx:latest`), so no substitute chart was needed.

## Problems found in the lecture material

| Where | What happened | Fix |
|---|---|---|
| 04 `helm lint my-app/` | the folder has only a bare `Chart.yaml`, no `my-app/` chart, so lint fails | moved `Chart.yaml` into `my-app/` ([details](04-chart-yaml/README.md#problem-found-helm-lint-my-app-has-no-chart-to-lint)) |
| 05 `helm install my-app ./chart` | `path "./chart" not found` | use the real chart folder `./my-app` ([details](05-values-yaml/README.md#problem-found-chart-does-not-exist)) |
| 05 options A and B | both install release `my-app`: `cannot re-use a name that is still in use` | prod install named `my-app-prod` ([details](05-values-yaml/README.md#problem-found-the-prod-install-reuses-the-release-name-my-app)) |
| 05 README vs file | README shows prod `tag: v2.0.0`, the file has `latest`; `nginx:v2.0.0` doesn't exist | kept the file ([details](05-values-yaml/README.md#note-the-readmes-prod-tag-differs-from-the-file)) |
| 06 values | values in the notes leave out `service.enabled`, so the conditional Service would never render | used the repo's values (which have it), showed the effect ([details](06-templates/README.md#4-addition-the-conditional-in-action)) |
| 08 `./app-chart` | chart lives in 07, not 08: `path not found` | `../07-install-upgrade/app-chart` ([details](08-rollback/README.md#problem-found-app-chart-isnt-in-this-folder)) |
| 09 release names | header uses `guestbook`, steps use `my-guestbook`; a second release fails on the hardcoded `nodePort: 30080` (cluster-wide) | followed `my-guestbook`, documented the clash, removed the failed release ([details](09-deploying-application/README.md#problem-found-release-name-guestbook-vs-my-guestbook-and-a-fixed-nodeport)) |
| 09 README vs file | README shows `image.tag: "1.24"`, `values.yaml` has `"latest"` | kept the file; noted that pinning is better ([details](09-deploying-application/README.md#note-the-values-files-image-tag-differs-from-the-readme)) |
| mini project step 13 | upgrade with `--set` only drops `values-prod.yaml`: replicas 3 → 1 and environment back to `development` | ran it as written, then the corrected `-f values-prod.yaml --set …` ([details](mini-project/README.md#problem-found-step-13-quietly-drops-the-production-values)) |

## Pending: needs the student

Nothing remote is required for this session: no registry, GitHub or cloud steps. The
folder only needs to be committed and pushed with the rest of the repo.

## What I understood

- Helm turns a set of Kubernetes YAML files into one versioned unit: a chart, installed
  as a named release. Install, upgrade, rollback and uninstall each act on all of the
  release's objects at once.
- Values are layered (chart defaults, then `-f` files, then `--set`), and an upgrade
  starts from the chart defaults again unless I pass my values again. Most of the
  surprises in this session came from that one rule.
- Every change is a numbered revision stored as a Secret in the namespace. That stored
  history is what makes `helm history`, `helm get` and `helm rollback` work, and a
  rollback is itself a new revision.
- Things that are cluster-wide (NodePorts) or unpinned (`latest` tags) break the promise
  that a chart behaves the same every time it's installed, so they belong in values and
  should be pinned.
