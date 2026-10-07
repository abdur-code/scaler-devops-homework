# Image-scan gate fix: python:3.12-slim (Debian 13) carried 44 HIGH CVEs, none with a
# Debian fix yet (util-linux, ncurses, systemd libs, perl-base), so
# `trivy image --severity HIGH,CRITICAL --exit-code 1` could never pass on it.
# The Alpine variant does not ship those packages at all.
# Pinned by digest: the build always starts from the exact base image that passed the
# Trivy gate (a tag like 3.12-alpine can be re-pointed at any time), and BuildKit can
# use a cached copy without asking Docker Hub, which rate-limited the act run (429).
# To move to a newer base: pull the tag, re-run the pipeline, then update the digest.
FROM python:3.12-alpine@sha256:1b668429b3511ab407d8e00648891631b0b1a4d7e15e3ca70f38ab5b91ad4ab4

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .

# pip is only needed while building. The base image's pip 25.0.1 has known CVEs, and
# bumping it to 26.2.1 was not enough: Trivy reads the SBOM pip ships for its vendored
# urllib3/msgpack/setuptools and found 4 HIGH there. So remove pip from the final image.
# apk upgrade picks up Alpine fixes released after the base image was built (zlib).
# --no-cache-dir keeps pip's download cache out of the image layer.
RUN apk upgrade --no-cache \
 && pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip

COPY app ./app

# Run as an unprivileged user. A numeric UID lets Kubernetes verify runAsNonRoot.
RUN adduser -D -H -u 10001 app
USER 10001

# app.py now binds to localhost unless HOST is set (SAST fix); in a container it must
# listen on all of the container's interfaces or nothing outside can reach it.
ENV HOST=0.0.0.0 \
    PORT=5001

EXPOSE 5001

# python running as PID 1 ignores SIGTERM, so `docker stop` (and pod termination)
# ended in a SIGKILL, exit 137. Python handles SIGINT and exits cleanly.
STOPSIGNAL SIGINT

CMD ["python", "app/app.py"]
