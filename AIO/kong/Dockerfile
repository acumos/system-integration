FROM buildpack-deps:bionic-curl
COPY config /var/acumos/config/.

ENTRYPOINT /var/acumos/config/configure_kong.sh
