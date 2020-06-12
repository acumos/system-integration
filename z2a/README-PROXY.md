# README-PROXY

If you are running `kind` in an environment that requires a proxy, you may need to configure `kind` to use that proxy.

You can configure kind to use a proxy using one or more of the following environment variables (uppercase takes precedence):

```sh
HTTP_PROXY or http_proxy
HTTPS_PROXY or https_proxy
NO_PROXY or no_proxy
```

## Editing the proxy.txt file  (Note: deprecated, subject to change)

The `proxy.txt` file is located in the `z2a/0-kind` directory.  This file needs to be edited such that the Docker installation can proceed cleanly.  We will need to change directories into that location to perform the necessary edits required for the Acumos installation.

This file will contain a single entry in the form of `hostname` OR `hostname:port` (this is not a URL).

Here is the `change directory` command to execute.

```sh
cd $HOME/src/system-integration/z2a/0-kind
```

Using your editor of choice (vi, nano, pico etc.) please open the `proxy.txt` file such that we can edit it's contents. Examples for the single-line entry required in this file are:

```sh
proxy-hostname.example.com
OR
proxy-hostname.example.com:3128
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

Last Edited: 2020-06-16
