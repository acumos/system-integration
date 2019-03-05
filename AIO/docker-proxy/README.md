# Acumos docker-proxy

This folder contains scripts, templates, and configuration data for deployment
of the Acumos docker-proxy service under docker and kubernetes.

## Boreas planned features and status

### Authenticated Access

**(implemented)** Restrict access for pulling and pushing images, by first
authenticating the user as a registered Acumos platform user.

### Pull Authorization

Verify that the user is authorized to pull an image, as the image meets any
of the criteria:

* is owned by the user
* is an open source image available in a marketplace
* is a non-open-source image for which the user has a "right-to-use" (RTU)
  of their own, or access per a RTU for all users of the Acumos platform

### Push Authorization

Verify that the user is authorized to push an image, as the image meets all of
the criteria:

* the image name (a combination of model name and solutionId) matches that of
  a model owned by the user
* the image tag (version) matches one of the user's solution revisions

### Logging

Logs of all operations will be created per the Acumos logging standard, and
collected by the ELK stack.

## Demo Guide

Following are notes illustrating the operation of the authenticated docker-proxy
service. To replicate the detailed example that follows:

### Prepare your workstation

Create and run this script to add the Acumos docker-proxy as an insecure
registry, and restart docker. NOTE: this will overwrite /etc/docker/daemon.json
if existing. If you have other insecure registries in that file, just add
another entry in the "insecure-registries" array, e.g.(30883 is the Acumos AIO
default port for the docker-proxy service)

```bash
,"<acumos_domain>:30883"
```

```bash
cat <<'EOF' >add_insecure_registry.sh
#!/bin/bash
dockerProxy=$1
if [[ $(sudo grep -c $dockerProxy /etc/docker/daemon.json) -eq 0 ]]; then
  echo "configure the docker service to allow access to the Acumos platform docker proxy as an insecure registry."
  cat << EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": [
    "$dockerProxy"
  ],
  "disable-legacy-registry": true
}
EOF
  sudo systemctl daemon-reload
  sudo service docker restart
fi
EOF
```

### Verify docker login

Verify that you can login to the Acumos docker registry via the docker-proxy

```bash
   $ docker login <acumos_domain>:30883 -u <username> -p <password>
```

You should see "Login Succeeded"

### Pull a model image

View the artifact details for a model on the Acumos platform, and try to
pull it. The docker image will be the artifact that follows the naming
convention "```<model_name>_<solutionId>:<version>```", e.g.

```bash
   $ docker pull <acumos_domain>:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1
```

### Push a model image

Verify that you can push an image to the Acumos registry by downloading
some image (e.g. httpd), tagging it per the name of the image you downloaded,
and pushing the updated image back to the Acumos registry, e.g.

```bash
   $ docker pull httpd
   $ docker tag httpd <acumos_domain>:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1
   $ docker push <acumos_domain>:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1
```

After tagging and pushing the image, you can verify that the updated image
was actually the image pushed, by listing the docker images on your
workstation, e.g. as below, where you can see the iris image as originally

```bash
   $ docker image list
   REPOSITORY                                                TAG                 IMAGE ID            CREATED             SIZE
   acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1   <none>              731eac61b57c        2 hours ago         1.46GB
   httpd                                                     latest              2d1e5208483c        2 weeks ago         132MB
   acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1   1                   2d1e5208483c        2 weeks ago         132MB
```

## Example Output

An example of these steps is provided below. As extra info, the output below
includes the log of the docker-proxy as it handles the individual HTTP requests
in the operations.

```bash
$ docker login acumos-lab:30883 -u test -p P@ssw0rd
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
127.0.0.1 - - [22/Mar/2019 23:22:10] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:22:10 +0000] "GET /v2/ HTTP/1.1" 200 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:22:11] "GET /auth HTTP/1.0" 200 0
WARNING! Your password will be stored unencrypted in /home/superuser/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
204.178.3.200 - - [22/Mar/2019:23:22:11 +0000] "GET /v2/ HTTP/1.1" 200 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"

$ docker pull acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1
127.0.0.1 - - [22/Mar/2019 23:22:22] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:22:22 +0000] "GET /v2/ HTTP/1.1" 200 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:22:22] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:22:23 +0000] "GET /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/manifests/1 HTTP/1.1" 200 2000 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
1: Pulling from iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1
7448db3b31eb: Already exists 
81a33a47e336: Already exists 
de23491efb8d: Already exists 
a79d5d9eeb58: Already exists 
fe5f4cef0050: Pulling fs layer 
5e4399bed6b2: Pulling fs layer 
2d0dd5a5e7e5: Pulling fs layer 
3d46a38a3388: Waiting 
127.0.0.1 - - [22/Mar/2019 23:22:23] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:22:23 +0000] "GET /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:731eac61b57c74557ae7b1da0e462c399a621d9baaf7466d39fb0120ebf61915 HTTP/1.1" 200 7861 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
5e4399bed6b2: Download complete 
204.178.3.200 - - [22/Mar/2019:23:22:23 +0000] "GET /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:5e4399bed6b2804274ec3cb9cc16615761d5cdc7cab14a4f2e7385a3fdf94a18 HTTP/1.1" 200 7395 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
fe5f4cef0050: Pull complete 
5e4399bed6b2: Extracting [==================================================>]  7.395kB/7.395kB
5e4399bed6b2: Pull complete 
2d0dd5a5e7e5: Downloading [=================================================> ]  177.9MB/178.6MB
3d46a38a3388: Downloading [=====================>                             ]  146.5MB/339.4MB
2d0dd5a5e7e5: Pull complete 
3d46a38a3388: Downloading [=================================================> ]  337.4MB/339.4MB
204.178.3.200 - - [22/Mar/2019:23:24:35 +0000] "GET /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:3d46a38a3388b99037a8b3ca114ea984d7524245bf31d32027aaab982b6a7587 HTTP/1.1" 200 339372267 "-" 3d46a38a3388: Pull complete 
Digest: sha256:c5a259588a925a1b77653843a17772416bb20f8e48596c711423952a03927b6e
Status: Downloaded newer image for acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1

$ docker tag httpd acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1

$ docker push acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1:1
The push refers to repository [acumos-lab:30883/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1]
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "GET /v2/ HTTP/1.1" 200 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
85f2134b775c: Preparing 
348e7202c3ba: Preparing 
6d3625e8d3b1: Preparing 
2882431cb66d: Preparing 
6744ca1b1190: Preparing 
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:9a4113020573f9f9d5b288ee3c768131f42bcd48b734d2ab44a5eba3b06d6e22 HTTP/1.1" 404 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:dae6fe3c5e81fce55ed1b582bd9fe2cd0c8ffd8a1ef56e4aba49526c9a7ebd9f HTTP/1.1" 404 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:84006542c6886808e4a237c4c382d5b3b471c8c10415e4b997f218acda71a306 HTTP/1.1" 404 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:33fc493aff90095281a8938d001dbe01c988c5765a392d2a4b52c84cff0b62f0 HTTP/1.1" 404 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:f7e2b70d04ae3f516c08c24d88de0f82699aaf3ee98af6eb208bd234136142b4 HTTP/1.1" 404 0 "-" "docker85f2134b775c: Pushing [==================================================>]     512B
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "POST /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/ HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "POST /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/ HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
85f2134b775c: Pushing [==================================================>]  3.584kB
eric os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
2882431cb66d: Pushing   2.56kB
eric os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:37] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:37 +0000] "POST /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/ HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:38] "GET /auth HTTP/1.0" 200 0
127.0.0.1 - - [22/Mar/2019 23:26:38] "GET /auth HTTP/1.0" 200 0
127.0.0.1 - - [22/Mar/2019 23:26:38] "GET /auth HTTP/1.0" 200 0
127.0.0.1 - - [22/Mar/2019 23:26:38] "GET /auth HTTP/1.0" 200 0
127.0.0.1 - - [22/Mar/2019 23:26:38] "GET /auth HTTP/1.0" 200 0
348e7202c3ba: Pushing [>                                                  ]  438.3kB/43.09MB
6d3625e8d3b1: Pushing [>                                                  ]  350.2kB/33.33MB
204.178.3.200 - - [22/Mar/2019:23:26:38 +0000] "PATCH /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/abd39b61-44f0-495a-8cde-3d2d3993ad61 HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:26:38] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:26:38 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/9d2dcf1e-f257-4a84-8abc-f04f7026161f?digest=sha256%3A9a4113020573f9f9d5b288ee3c768131f42bcd48b734d2ab44a5eba3b06d6e22 HTTP/1.1" 201 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
85f2134b775c: Pushed 
204.178.3.200 - - [22/Mar/2019:23:26:38 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/abd39b61-44f0-495a-8cde-3d2d3993ad61?digest=sha256%3A84006542c6886808e4a237c4c382d5b3b471c8c10415e4b997f218acda71a306 HTTP/1.1" 201 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
2882431cb66d: Pushed 
127.0.0.1 - - [22/Mar/2019 23:26:39] "GET /auth HTTP/1.0" 200 0
348e7202c3ba: Pushing [==================>                                ]  16.04MB/43.09MB
6d3625e8d3b1: Pushing [==================================================>]  34.61MB
348e7202c3ba: Pushing [====================>                              ]  17.41MB/43.09MB
6744ca1b1190: Pushing [====================>                              ]  22.25MB/55.28MB
204.178.3.200 - - [22/Mar/2019:23:26:58 +0000] "PATCH /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/71b44a09-bc7c-45d4-8a52-2d722c221aca HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 gi
348e7202c3ba: Pushing [=====================>                             ]  18.79MB/43.09MB
6744ca1b1190: Pushing [=====================>                             ]  23.87MB/55.28MB
204.178.3.200 - - [22/Mar/2019:23:26:59 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/71b44a09-bc7c-45d4-8a52-2d722c221aca?digest=sha256%3Adae6fe3c5e81fce55ed1b582bd9fe2cd0c8ffd8
348e7202c3ba: Pushing [==================================================>]  43.59MB
6d3625e8d3b1: Pushed 
204.178.3.200 - - [22/Mar/2019:23:27:00 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:dae6fe3c5e81fce55ed1b582bd9fe2cd0c8ffd8a1ef56e4aba49526c9a7ebd9f HTTP/1.1" 200 0 "-" "docker
6744ca1b1190: Pushing [==================================================>]  58.45MB
204.178.3.200 - - [22/Mar/2019:23:27:15 +0000] "PATCH /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/3c88d4b2-394b-4236-b817-01c95286be02 HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
204.178.3.200 - - [22/Mar/2019:23:27:15 +0000] "PATCH /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/2ac33d12-e7b8-43e7-bc8c-1d6b7ad3d448 HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:15] "GET /auth HTTP/1.0" 200 0
127.0.0.1 - - [22/Mar/2019 23:27:15] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:16 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/3c88d4b2-394b-4236-b817-01c95286be02?digest=sha256%3Af7e2b70d04ae3f516c08c24d88de0f82699aaf3ee98af6eb208bd234136142b4 HTTP/1.1" 201 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
204.178.3.200 - - [22/Mar/2019:23:27:16 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/2ac33d12-e7b8-43e7-bc8c-1d6b7ad3d448?digest=sha256%3A33fc493aff90095281a8938d001dbe01c988c5765a392d2a4b52c84cff0b62f0 HTTP/1.1" 201 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:16] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:16 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:f7e2b70d04ae3f516c08c24d88de0f82699aaf3ee98af6eb208bd234136142b4 HTTP/1.1" 200 0 "-" "docker348e7202c3ba: Pushed 
127.0.0.1 - - [22/Mar/2019 23:27:16] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:16 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:33fc493aff90095281a8938d001dbe01c988c5765a392d2a4b52c84cff0b62f0 HTTP/1.1" 200 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:16] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:16 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:2d1e5208483c26822b518c4ffa34ce1cd960f3e90e9be6ffe4c52cc6f5d5492c HTTP/1.1" 404 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:17] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:17 +0000] "POST /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/ HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:17] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:17 +0000] "PATCH /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/fa621277-50d7-444f-9057-dd72defc6e74 HTTP/1.1" 202 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:18] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:18 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/uploads/fa621277-50d7-444f-9057-dd72defc6e74?digest=sha256%3A2d1e5208483c26822b518c4ffa34ce1cd960f3e90e9be6ffe4c52cc6f5d5492c HTTP/1.1" 201 5 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:18] "GET /auth HTTP/1.0" 200 0
204.178.3.200 - - [22/Mar/2019:23:27:18 +0000] "HEAD /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/blobs/sha256:2d1e5208483c26822b518c4ffa34ce1cd960f3e90e9be6ffe4c52cc6f5d5492c HTTP/1.1" 200 0 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
127.0.0.1 - - [22/Mar/2019 23:27:18] "GET /auth HTTP/1.0" 200 0
1: digest: sha256:d93278029af342292a3af350bfb3d89edbe064f1d5c82f6841cb6abf79902875 size: 1367
204.178.3.200 - - [22/Mar/2019:23:27:19 +0000] "PUT /v2/iris_9d294c20-7b1f-4ab7-b8b3-03bc7f069ac1/manifests/1 HTTP/1.1" 201 1367 "-" "docker/18.06.3-ce go/go1.10.3 git-commit/d7080c1 kernel/4.15.0-46-generic os/linux arch/amd64 UpstreamClient(Docker-Client/18.06.3-ce \x5C(linux\x5C))"
```
