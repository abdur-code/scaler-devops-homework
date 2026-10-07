# Session 16: CI/CD and GitHub Actions

**Name:** Abdur Rahman Ibne Munir
**Enrollment number:** 24BCS10244

This session is about automating the path from `git push` to a deliverable build. I worked
through every part of the lecture (CI vs CD, the pipeline stages, workflows, jobs, steps,
runners, secrets, artifacts, and the build-and-test pipeline). I rebuilt the instructor's
`demo/` project from scratch, including the student hands-on task, and turned the lecture's
`10-final-cicd-pipeline` into a complete CI/CD project. For that project I added a
`Dockerfile` and a CD stage that builds, smoke-tests and (on `main` only) pushes a container
image to GitHub Container Registry. GitHub itself was not used: every workflow was executed
locally with [`act`](https://github.com/nektos/act), which runs the same YAML files in Docker
containers. The screenshots are my own terminal. Pushing the final project to GitHub is the
one step left, listed at the end.

## Homework task → where to find it

| Homework item | Folder |
|---|---|
| CI vs CD, CI/CD pipeline | [`01-ci-cd-concepts/`](01-ci-cd-concepts/) |
| GitHub Actions, workflows, jobs, steps, runners | [`02-workflows-jobs-runners/`](02-workflows-jobs-runners/) |
| Secrets, artifacts | [`03-secrets-and-artifacts/`](03-secrets-and-artifacts/) |
| Build, test, pipeline execution (pass → fail → fix) | [`04-build-and-test/`](04-build-and-test/) |
| Instructor demo walkthrough + student hands-on task | [`05-demo-project/`](05-demo-project/) |
| **Final project**: application source code, Dockerfile, GitHub Actions workflow, CI pipeline, CD pipeline, screenshots of pipeline execution, README | [`final-cicd-project/`](final-cicd-project/) |

Lecture → folder: `01-ci-vs-cd` + `02-cicd-pipeline` → `01`; `03-github-actions`,
`04-workflows`, `05-jobs-and-steps`, `06-runners` → `02`; `07-secrets`, `08-artifacts` → `03`;
`09-build-and-test` → `04`; `demo/` → `05`; `10-final-cicd-pipeline` → `final-cicd-project`.

## Folder structure

```text
15-github-actions/
├── 01-ci-cd-concepts/            README + 2 simulation scripts (borrowed from the older notes)
├── 02-workflows-jobs-runners/    .github/workflows/: hello-actions, workflow-demo, jobs-steps,
│                                 jobs-steps-needs (addition), runner-demo
├── 03-secrets-and-artifacts/     .github/workflows/: secrets-demo, artifact-demo; build.sh
├── 04-build-and-test/            app/, tests/, build.sh, requirements.txt, .github/workflows/ci.yml
├── 05-demo-project/              the demo project after the hands-on task (power())
├── final-cicd-project/           app/, tests/, build.sh, Dockerfile, .dockerignore,
│                                 .github/workflows/ci-cd.yml
├── .gitignore                    build/, caches, local act artifacts
└── README.md
```

Every subfolder has its own `README.md` and a `screenshots/` folder: 52 screenshots in
total (2 + 7 + 5 + 9 + 12 + 17). Each `act` run was piped through `tee` and `grep`, so the
screenshots show a filtered view of the run; the full output was only kept locally.

## Environment notes

- **Machine:** macOS on Apple Silicon, Docker Desktop, act 0.2.89, Homebrew Python 3.14.
  This session doesn't use Kubernetes, so no namespace was needed.
- **GitHub Actions → act.** Wherever the notes say "push, then open the Actions tab", I ran
  `act <event>` instead. Workflows that only have `workflow_dispatch` were started with
  `act workflow_dispatch`, the others with `act push`. Flags used on every run:
  - `-P ubuntu-latest=catthehacker/ubuntu:act-latest`: the runner image, passed
    explicitly (no `~/.actrc`). It has an arm64 build, so I didn't need
    `--container-architecture linux/amd64`. The "Apple M-series" warning act prints on
    every run is harmless.
  - `--pull=false`: the image was pulled once and isn't re-pulled for every job.
  - `--no-cache-server`: act otherwise opens a cache server on a random port, and no
    workflow here uses `actions/cache`.
  - `--artifact-server-port 18160 --artifact-server-path <dir>`: act's local artifact
    server, moved from its default port 34567 to my assigned range (18160–18169).
  - `-s DEMO_SECRET=hello-github-actions`: the lecture's fake demo secret.
- **Differences between act and GitHub** that show up in the screenshots: the runner
  hostname is `docker-desktop` and the CPU is `aarch64`; times are in UTC; act copies the
  local folder instead of cloning; skipped steps are not printed; the "artifact download
  URL" is fake; `github.repository` comes from the local git remote (see
  `final-cicd-project`, step 15).
- **Python:** global `pip install` is blocked on Homebrew Python (PEP 668), so I used a
  virtual environment kept outside the homework repo (failure and fix in
  `04-build-and-test`, step 2).
- **Git:** the lecture's `git init` / `add` / `commit` steps for the demo and final projects
  were done in scratch copies **outside** this homework repo, with a repo-local identity
  and no remote. Nothing was pushed anywhere, and no image was pushed to a registry. The
  folders here are copies of those projects' final state (without `.git/`).
- **Action versions:** `actions/checkout@v6` and `actions/setup-python@v7` from the notes
  exist and work; no version fix was needed (`02-workflows-jobs-runners`, step 1).
- **Cleanup:** `build/`, `.pytest_cache/`, `__pycache__/`, the local artifact folder and
  the Docker images built during the session were removed.

## Problems found in the lecture material

| Where | Problem | Root cause | Fix |
|---|---|---|---|
| `09`, `10`: `python3 -m pip install -r requirements.txt` | `error: externally-managed-environment` | Homebrew Python is marked externally managed (PEP 668) | install inside a venv (the `demo/` notes already do this) |
| `09` README, "Run Application" | expects a fixed printout `10 + 5 = 15 …`; the program actually waits for input | the README describes an older, non-interactive `calculator.py` | typed the calculations at the prompt; results print as `Result: 15.0` |
| `demo/` README, section 4 | the code shown splits input on spaces; `demo/app/calculator.py` uses a regex (also accepts `3+5`) | README and file drifted apart | used the file |
| `10` README, failure scenario | says only the build is skipped when tests fail | `security-check` also has `needs: test` | observed both skipped (`final-cicd-project`, step 7) |

None of these broke a workflow. All lecture workflows ran as written.

---

## Pending: needs the student

These steps need my GitHub account, so they are not done yet. The `gh` CLI on this Mac is
logged in to my **work** account; the homework account is **`abdur-code`**.

```bash
# 1. Make the final project its own repository (workflows only run from .github/ at the repo root)
cp -R ~/Desktop/SST/scaler-devops-homework/15-github-actions/final-cicd-project ~/session16-cicd-github-actions
cd ~/session16-cicd-github-actions
git init -b main
git config user.name "abdur-code"
git config user.email "abdurrahmanim2422@gmail.com"
git add .
git commit -m "Add CI/CD pipeline with GitHub Actions"

# 2. Switch gh to the personal account (run `gh auth login` first if abdur-code isn't listed)
gh auth status
gh auth switch --hostname github.com --user abdur-code

# 3. Create the empty repo and connect it over the personal SSH host alias
gh repo create abdur-code/session16-cicd-github-actions --public --description "Session 16: CI/CD with GitHub Actions"
git remote add origin git@github-personal:abdur-code/session16-cicd-github-actions.git

# 4. Add the secret BEFORE the first push (without it the build job fails and CD never runs)
gh secret set DEMO_SECRET --body "hello-github-actions" --repo abdur-code/session16-cicd-github-actions
gh secret list --repo abdur-code/session16-cicd-github-actions
#    (web alternative: repo → Settings → Secrets and variables → Actions → New repository secret,
#     Name DEMO_SECRET, Value hello-github-actions)

# 5. Push: this triggers the "CI/CD Pipeline" (push to main, so the image IS pushed to ghcr.io)
git push -u origin main

# 6. Watch and inspect the run
gh run list  --repo abdur-code/session16-cicd-github-actions
gh run watch --repo abdur-code/session16-cicd-github-actions
gh run view <run-id> --repo abdur-code/session16-cicd-github-actions --log
gh run view <run-id> --repo abdur-code/session16-cicd-github-actions --web
gh run download <run-id> --repo abdur-code/session16-cicd-github-actions -n calculator-build -D calculator-build

# 7. Check the published image (https://github.com/abdur-code?tab=packages → session16-calculator)
docker pull ghcr.io/abdur-code/session16-calculator:latest
#    New GHCR packages start out private. Either make it public (package → Package settings →
#    Change visibility), or log in first:
#    gh auth refresh -s read:packages && gh auth token | docker login ghcr.io -u abdur-code --password-stdin

# 8. Switch gh back to the work account afterwards
gh auth switch --hostname github.com --user <work-account>
```

Without `gh`: create the repo on github.com while logged in as `abdur-code`, add the
secret in the web UI as in step 4, then do steps 1, 3 (only `git remote add …`) and 5 from
the terminal. The `github-personal` SSH alias already points at the personal key.

Screenshots to add afterwards (save into `final-cicd-project/screenshots/` with the same
naming): the green run in the Actions tab with all four jobs, the run Summary showing the
`calculator-build` artifact, and the `session16-calculator` package page. Optional: repeat
the break/fix cycle from `final-cicd-project` steps 6–8 with real pushes to get a red run
followed by a green one.
