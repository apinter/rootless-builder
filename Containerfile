FROM quay.io/containers/buildah

RUN dnf upgrade -y
RUN dnf install -y nodejs18 git podman -y && \
    ln -s /usr/bin/node-18 /usr/bin/node
