# README-PROXY

TL;DR

If you are behind a proxy; here is the list of items that need to be configured:

* package manager application (apt/yum)
* user environment (.profile, .bashrc, .kshrc etc.)
* docker client
* docker service
* MITM (man-in-the-middle) SSL certificate considerations


If you are running `kind` in an environment that requires a proxy for Internet access, you may need to configure `kind` to use that proxy.

You can configure `kind` to use a proxy using one or more of the following environment variables (uppercase takes precedence):

```sh
http_proxy=
https_proxy=
no_proxy=
HTTP_PROXY=
HTTPS_PROXY=
NO_PROXY=
```

### Proxy Rework TODO list
>
#### TODO: review proxies (in general) including Docker Proxy and k8s tooling proxies
>
> * get users to fully populate proxy.txt with:
> * http_proxy, https_proxy, and no_proxy assignments...
>
#### TODO: force proxy OFF in the install scripts
>
> * except for where we download utils from the internet...
>
#### TODO: use 3 vars to spit out a .docker/config.json
>
> * provide instructions for the user to install themselves (STARTED)

----- Addendum -----

```bash
log "Creating the systemd docker.service directory ...."
# Create the systemd docker.service directory
sudo mkdir -p /etc/systemd/system/docker.service.d

# Setup Docker daemon proxy entries.
PROXY_CONF=$Z2A_BASE/0-kind/proxy.txt
[[ -f $PROXY_CONF ]] && {
	PROXY=$(<$PROXY_CONF) ;
	if [[ -n $PROXY ]] ; then
		log "Configuring /etc/systemd/system/docker.service.d/http-proxy.conf file ...."
		cat <<EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://$PROXY"
Environment="HTTPS_PROXY=http://$PROXY"
Environment="NO_PROXY=127.0.0.1,localhost,.svc,.local,kind-acumos-control-plane,169.254.0.0/16,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
EOF
	fi
}

# Reload docker service configuration
sudo systemctl daemon-reload
```

----- End Addendum -----

```sh
// Created: 2020/06/16
// Last modified: 2020/07/07
```
