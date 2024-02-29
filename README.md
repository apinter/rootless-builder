# Rootless builder

A simple container image for building containers using _buildah_, _podman_, _Gitea/Github Actions_.

## Example pipline configuration

```yaml
name: Build image using rootless builder
run-name: ${{ gitea.actor }} is testing 🚀
on:
  push:
    branches: [ main ]

jobs:
  build:
    name: Build and push image
    runs-on: ubuntu-latest
    container:
      image: docker.io/adathor/rootless-builder:latest
      options: --security-opt label=disabled --device /dev/fuse ## buildah needs fuse to work
    #   credentials: ## If pulling from a private registry
        # username: ${{ secrets.DOCKER_REGISTRY_USER }}
        # password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
    steps:
    - uses: actions/checkout@v2
    - name: Build Image
      id: build-image
      uses: redhat-actions/buildah-build@v2
      with:
        image: test
        tags: latest ${{ github.sha }}
        containerfiles: |
          ./Containerfile
    - name: Push To Dockerhub
      id: push-to-docker
      uses: redhat-actions/push-to-registry@v2
      with:
        image: ${{ steps.build-image.outputs.image }}
        tags: ${{ steps.build-image.outputs.tags }}
        registry: registry.adathor.com/dewhoops/test
        username: ${{ secrets.DOCKER_REGISTRY_USER }}
        password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
```

## Gitea runner

1. Get a registration token from your Gitea instance
1. Install _podman_ and _docker_ on the host, and enable `podman.socket` service for the user that will run the runner (`systemctl --user enable --now podman.socket`)
   - Could work without _docker_ installed, just make a symlink from `/usr/bin/podman` to `/usr/bin/docker`
1. Create a runner using the token:

  ```bash
  podman run \
    --authfile=$HOME/.secret/auth.json \
    -v $PWD/config.yaml:/config.yaml:z \
    -v $PWD/data:/data:z \
    -v /run/user/1000/podman/podman.sock:/var/run/docker.sock \
    --security-opt label=disable \ ## If SELinux is enabled
    -e CONFIG_FILE=/config.yaml \
    -e GITEA_INSTANCE_URL=https://gitea.adathor.com \
    -e GITEA_RUNNER_REGISTRATION_TOKEN=SuperSecretSquirrel \
    -e GITEA_RUNNER_NAME=kazeshini \
    -e GITEA_RUNNER_LABELS="ubuntu-latest:docker://node:16-bullseye" \
    --name gitea-runner \
    -d docker.io/gitea/act_runner:latest
  ```

Since the _Gitea_ and _Github actions_ are interoperable follow the [Github instructions](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners) for the runner deployment.


### Podman quadlet

`$HOME/.config/containers/systemd/gitea-runner.yml`: 

```yaml
---
apiVersion: v1
kind: Pod
metadata:
  annotations:
    io.containers.autoupdate: "registry"
  labels:
    app: gitea-runner-pod
  name: gitea-runner-pod
spec:
  containers:
  - name: gitea-runner
    image: docker.io/gitea/act_runner:latest
    securityContext:
      seLinuxOptions:
        type: spc_t
    env:
    - name: GITEA_INSTANCE_URL
      value: https://gitea.adathor.com
    - name: GITEA_RUNNER_REGISTRATION_TOKEN
      valueFrom:
        secretKeyRef:
          name: gitea-runner-regtoken
          key: gitea-runner-token
    - name: GITEA_RUNNER_NAME
      value: vegas
    - name: GITEA_RUNNER_LABELS
      value: ubuntu-latest:docker://node:16-bullseye
    - name: CONFIG_FILE
      value: /config.yaml
    volumeMounts:
    - mountPath: /data
      name: home-podman_vol-gitea-data-host-0
    - mountPath: /var/run/docker.sock
      name: run-user-1000-podman-podman.sock-host-1
    - mountPath: /config.yaml
      name: home-podman_vol-gitea-config.yaml-host-2
  volumes:
  - hostPath:
      path: /home/podman_vol/gitea/data
      type: Directory
    name: home-podman_vol-gitea-data-host-0
  - hostPath:
      path: /run/user/1000/podman/podman.sock
      type: File
    name: run-user-1000-podman-podman.sock-host-1
  - hostPath:
      path: /home/podman_vol/gitea/config.yaml
      type: File
    name: home-podman_vol-gitea-config.yaml-host-2
---
apiVersion: v1
kind: Secret
metadata:
  name: gitea-runner-regtoken
data:
  gitea-runner-token: U3VwZXJTZWNyZXRTcXVpcnJlbA==

```

`$HOME/.config/containers/systemd/gitea-runner.yml`:

```bash
[Unit]
After=home-podman_vol.mount gitea.service

[Install]
WantedBy=default.target

[Kube]
Yaml=$HOME/.config/containers/systemd/gitea-runner.yml

[Service]
TimeoutStartSec=900
ExecStartPre=/usr/bin/sleep 5
```
