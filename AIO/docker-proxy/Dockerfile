FROM nginx:stable
# Per https://torstenwalter.de/openshift/nginx/2017/08/04/nginx-on-openshift.html
# support running as arbitrary user which belogs to the root group
RUN chmod g+rwx /var/cache/nginx /var/run /var/log/nginx

COPY auth/domain.crt /etc/nginx/conf.d/domain.crt
COPY auth/domain.key /etc/nginx/conf.d/domain.key
COPY auth/acumos_auth.py /etc/nginx/conf.d/acumos_auth.py
COPY auth/nginx.conf /etc/nginx/nginx.conf
RUN apt-get update && apt-get --no-install-recommends install -y python python-pip && pip install requests

ENTRYPOINT (python /etc/nginx/conf.d/acumos_auth.py &) && nginx -g "daemon off;"
