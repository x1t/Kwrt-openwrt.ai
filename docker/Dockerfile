FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG GO_BOOTSTRAP_VERSION=1.24.13
ARG GO_BOOTSTRAP_SHA256=74d97be1cc3a474129590c67ebf748a96e72d9f3a2b6fef3ed3275de591d49b3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        android-sdk-libsparse-utils aria2 bash binutils build-essential bzip2 \
        ca-certificates ccache clang curl device-tree-compiler file flex g++ \
        gawk gettext git jq libelf-dev libfuse-dev libgmp3-dev liblzma-dev \
        libmpc-dev libncurses-dev libpython3-dev libssl-dev llvm make \
        ninja-build patch pigz python3 python3-pyelftools python3-setuptools \
        qemu-utils rename rsync subversion swig unzip wget xsltproc zlib1g-dev \
        zstd \
    && rm -rf /var/lib/apt/lists/* \
    && curl --fail --location --retry 3 --retry-all-errors --silent --show-error \
        "https://go.dev/dl/go${GO_BOOTSTRAP_VERSION}.linux-arm64.tar.gz" \
        --output /tmp/go-bootstrap.tar.gz \
    && printf '%s  %s\n' "$GO_BOOTSTRAP_SHA256" /tmp/go-bootstrap.tar.gz \
        | sha256sum --check --status \
    && mkdir -p /opt/go-bootstrap \
    && tar -xzf /tmp/go-bootstrap.tar.gz -C /opt/go-bootstrap --strip-components=1 \
    && rm /tmp/go-bootstrap.tar.gz \
    && /opt/go-bootstrap/bin/go version \
    && mkdir -p /build /cache /artifacts \
    && chown -R ubuntu:ubuntu /build /cache /artifacts

COPY --chown=ubuntu:ubuntu docker/build-onecloud.sh /usr/local/bin/build-onecloud
RUN chmod 0755 /usr/local/bin/build-onecloud

USER ubuntu
WORKDIR /build

ENTRYPOINT ["/usr/local/bin/build-onecloud"]
