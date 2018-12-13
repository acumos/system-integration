# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2018 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T and Tech Mahindra
# under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# This file is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ===============LICENSE_END=========================================================
# https://github.com/elastic/logstash-docker
FROM docker.elastic.co/logstash/logstash-oss:6.4.3
COPY config/logstash.yml /usr/share/logstash/config/logstash.yml
COPY pipeline /usr/share/logstash/pipeline
RUN /usr/share/logstash/bin/logstash-plugin install --version "4.3.0" logstash-input-jdbc
ADD https://downloads.mariadb.com/enterprise/1prc-8jnh/connectors/java/connector-java-2.1.0/mariadb-java-client-2.1.0.jar /usr/share/logstash/vendor/bundle/
USER root
RUN chown -R root:root /usr/share/logstash
RUN ls -al /usr/share/logstash/vendor/bundle \
  && chmod a+r /usr/share/logstash/vendor/bundle/mariadb-java-client-2.1.0.jar
