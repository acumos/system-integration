#
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2017-2020 AT&T Intellectual Property & Tech Mahindra.
# All rights reserved.
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
# ===============LICENSE_END========================================================
#
# Alpine linux would be great for this, but it's DNS does not use search paths.
FROM ubuntu

RUN apt-get update
RUN apt-get -y --no-install-recommends install socat

RUN echo '#!/bin/bash' > /start.sh
RUN echo 'exec socat ${5:+-T$5} ${1^^}-LISTEN:$2,reuseaddr,fork ${1^^}:$3:$4' >> /start.sh
RUN chmod 755 /start.sh

# Usage: docker run -p <host-port>:<port> <this-container> <tcp|udp> <port> <service-name> <service-port> [timeout]
ENTRYPOINT ["/start.sh"]
