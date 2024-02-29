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
      options: --device /dev/fuse ## buildah needs fuse to work
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
