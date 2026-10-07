#!/usr/bin/env bash
# Install a pinned, checksum-verified scanner binary for the CI jobs.
#   usage: install-scanner.sh gitleaks|trivy
#
# Release binaries are downloaded straight from the projects' GitHub releases and
# checked against the SHA-256 sums below, instead of piping an install script into a
# shell or using a third-party action. x64 is what GitHub-hosted runners use; arm64 is
# for running the workflow locally with `act` on an Apple Silicon Mac.
set -euo pipefail

GITLEAKS_VERSION=8.30.1
TRIVY_VERSION=0.75.0

arch="$(uname -m)"
case "$1:$arch" in
  gitleaks:x86_64)
    url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
    sum=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
  gitleaks:aarch64)
    url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_arm64.tar.gz"
    sum=e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080 ;;
  trivy:x86_64)
    url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
    sum=c6e65abddb348e25f10549df887045629cf28cc72453cd1c63acb717316b3f3f ;;
  trivy:aarch64)
    url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-ARM64.tar.gz"
    sum=a1ee9f6ffb7d112b64ff726a2a0717c21175c1114361391f4a132956751a13b3 ;;
  *) echo "unsupported: $1 on $arch" >&2; exit 1 ;;
esac

bin_dir="${RUNNER_TEMP:-/tmp}/bin"
mkdir -p "$bin_dir"
tarball="$(mktemp)"
curl -sSfL -o "$tarball" "$url"
echo "$sum  $tarball" | sha256sum -c -
tar -xzf "$tarball" -C "$bin_dir" "$1"
rm -f "$tarball"
echo "$bin_dir" >> "${GITHUB_PATH:-/dev/null}"
"$bin_dir/$1" version
