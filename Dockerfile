# syntax=docker/dockerfile:1.4

ARG FROM
FROM ${FROM}

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN <<EOF bash -xe
  apt-get update
  apt-get install -y --no-install-recommends \
    build-essential \
    crudini \
    curl \
    git \
    lsb-release \
    openssh-client \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF

# Add GitHub keys to avoid issues with cloning repositories
RUN <<EOF bash -xe
  mkdir -p -m 0700 ~/.ssh
  ssh-keyscan github.com >> ~/.ssh/known_hosts
EOF

# Configure wheel mirror for faster virtual environment builds.
RUN <<EOF bash -xe
  crudini --set /etc/pip.conf \
    global \
    extra-index-url \
    $(curl -s https://opendev.org/opendev/zone-opendev.org/raw/branch/master/zones/opendev.org/zone.db | \
        grep ^mirror\\. | \
        awk '{ print $1".opendev.org" }' | \
        xargs -n1 -I{} curl -m 1 -r 0-102400 -s -w "%{speed_download} %{url_effective}\n" -o /dev/null https://{} | \
        sort -g -r | \
        head -1 | \
        cut -d' ' -f2)wheel/ubuntu-$(lsb_release -rs)-$(uname -m)
EOF

# Create virtual environment
RUN <<EOF bash -xe
  python3 -m venv /var/lib/openstack
  /var/lib/openstack/bin/pip3 install -U pip wheel
EOF

# Build the virtual environment
ONBUILD ARG RELEASE
ONBUILD ADD https://releases.openstack.org/constraints/upper/${RELEASE} /upper-constraints.txt
ONBUILD ARG PROJECT
ONBUILD RUN sed -i "/^${PROJECT}==.*/d" /upper-constraints.txt
ONBUILD ARG PROJECT_REPO=https://opendev.org/openstack/${PROJECT}
ONBUILD RUN --mount=type=ssh git clone ${PROJECT_REPO} /src
ONBUILD ARG PROJECT_REF
ONBUILD RUN --mount=type=ssh <<EOF
  git -C /src fetch origin ${PROJECT_REF}
  git -C /src checkout FETCH_HEAD
EOF
ONBUILD ARG PIP_PACKAGES=""
ONBUILD COPY --from=bindep --link /runtime-pip-packages /runtime-pip-packages
ONBUILD RUN --mount=type=cache,target=/root/.cache <<EOF bash -xe
  /var/lib/openstack/bin/pip3 install \
    --only-binary :all: \
    --constraint /upper-constraints.txt \
    /src \
    ${PIP_PACKAGES} \
    $(cat /runtime-pip-packages | tr '\n' ' ')
EOF
