# Container image for the Session 16 calculator (the CD part of the pipeline).
#
# The image packages the output of the CI build, not the raw source:
#   locally:      ./build.sh && docker build -t session16-calculator:local .
#   in the CI/CD: the "Docker Image (CD)" job downloads the calculator-build
#                 artifact into build/ and then runs docker build.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Run as a normal user instead of root.
RUN useradd --create-home --uid 10001 calculator

# build/ contains calculator.py and build-info.txt (created by build.sh).
COPY build/ /app/

USER calculator

# calculator.py is interactive, so run the container with -it
# (or pipe input into it with -i).
ENTRYPOINT ["python", "calculator.py"]
