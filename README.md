# Docker image for `openstack-builder`

This is a simple image which use the `ONBUILD` instructions in order to be able
to build a complete virtual environment for any OpenStack project.  It uses a
few build arguments to tune the exact build environment.

The following images are published for all the different OpenStack releases:

- Ubuntu Focal (20.04 LTS): `quay.io/vexxhost/openstack-builder-focal:latest`
- Ubuntu Jammy (22.04 LTS): `quay.io/vexxhost/openstack-builder-jammy:latest`

The images published are also multi-architecture so they will allow you to build
for both `linux/amd64` and `linux/arm64`.

## Build arguments

There are two steps of build arguments, the ones being used to generate the
build image and the ones which are being used to build the projects when using
the API that the image exposes.

In order to build the image, you need to pass the following build arguments:

- `FROM`: Base image (currently only Ubuntu-based images are supported).

With the generated image, you can use it build arguments when using this image
as `FROM` to build the OpenStack project virtual environment.

- `RELEASE`: OpenStack release (e.g. `xena`).
- `PROJECT`: OpenStack project (e.g. `nova`).
- `PROJECT_REPO`: Project repository (defaults to `https://opendev.org/openstack/${PROJECT}`).
- `PROJECT_REF`: Project repository reference (recommend to be a commit SHA).
- `PIP_PACKAGES`: Additional list of Python packages to install (separated by spaces).

> **Note**
>
> It is strongly recommended to ensure that `PROJECT_REF` is a commit SHA in
> order to make images reproducible.  Otherwise, the Docker cache will likely
> never rebuild a new image (or unpredictable behavior will occur).

In addition, there must be a `bindep` stage in the same `Dockerfile` which
generates a file called `/runtime-pip-packages`.  You could generate that stage
by using something like this:

```Dockerfile
FROM quay.io/vexxhost/bindep:v2.11.0 AS bindep
ARG LOCI_TAG=2537db07aa3a3836cd215281e2fe2aa7923706b0
ADD https://opendev.org/openstack/loci/raw/commit/${LOCI_TAG}/bindep.txt /bindep.txt
ADD https://opendev.org/openstack/loci/raw/commit/${LOCI_TAG}/pydep.txt /pydep.txt
ARG PROJECT
ARG PROFILES
RUN bindep -f /bindep.txt -b -l newline ${PROJECT} ${PROFILES} python3 > /runtime-dist-packages
RUN bindep -f /pydep.txt -b -l newline ${PROJECT} ${PROFILES} python3 > /runtime-pip-packages
```

The example above leverages the LOCI project in order to take advantage of it's
vast and in-depth `bindep.txt` and `pydep.txt` dependency tracking for OpenStack
projects.
