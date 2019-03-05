#!/usr/bin/env python
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2018-2019 AT&T Intellectual Property. All rights reserved.
# ===================================================================================
# This Acumos software file is distributed by AT&T
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
#
# What this is: Script based upon the acumos python library
# (https://pypi.org/project/acumos/), to push a model to the Acumos platform
# from a JupyterLab notebook.
#
# How to use:
#   Set the following prior to calling this script, as in this example
#   os.environ['ACUMOS_USERNAME'] = "test"
#   os.environ['ACUMOS_PASSWORD'] = "P@ssw0rd"
#   os.environ['ACUMOS_TOKEN'] = "171cfda8dfa24edf8dfbc3dd681d8562"
#   os.environ['ACUMOS_DUMPDIR'] = "iris_sklearn"
#   Call the script
#   python acumos-push.py
#
# Status: this is a work in progress, under test.
#
import subprocess
import sys
import requests
import os
from os.path import extsep, exists, abspath, dirname, isdir, isfile, expanduser, relpath, basename, join as path_join
from collections import namedtuple
_ServerResponse = namedtuple('ServerResponse', 'status_code reason text')
from acumos.session import get_jwt, clear_jwt
from acumos.auth import _authenticate
from acumos.exc import AcumosError
from acumos.logging import get_logger
logger = get_logger(__name__)

# tokenMode is defined in the spring environment for the portal-be
tokenMode = os.environ['ACUMOS_ONBOARDING_TOKENMODE']
username = os.environ['ACUMOS_USERNAME']
password = os.environ['ACUMOS_PASSWORD']
jwt = os.environ['ACUMOS_TOKEN']
push_api = os.environ['ACUMOS_ONBOARDING_CLIPUSHURL']
auth_api = os.environ['ACUMOS_ONBOARDING_CLIAUTHURL']
dump_dir = os.environ['ACUMOS_DUMPDIR']
tries = 0
max_tries = 1
extra_headers = None

def _post_model(files, push_api, auth_api, tries, max_tries, extra_headers):
    '''Attempts to post the model to Acumos'''
    if tokenMode == "jwtToken":
        headers = {'Authorization': _authenticate(auth_api)}
    else:
        headers = {'Authorization': get_jwt(auth_api)}
    if extra_headers is not None:
        headers.update(extra_headers)

    r = requests.post(push_api, files=files, headers=headers)

    if r.status_code == 201:
        logger.info("Model pushed successfully to {}".format(push_api))
    else:
        clear_jwt()
        if r.status_code == 401 and tries != max_tries:
            logger.warning('Model push failed due to an authorization failure. Clearing credentials and trying again')
            _post_model(files, push_api, auth_api, tries + 1, max_tries, extra_headers)
        else:
            raise AcumosError("Model push failed: {}".format(_ServerResponse(r.status_code, r.reason, r.text)))

with open(path_join(dump_dir, 'model.zip'), 'rb') as model, \
    open(path_join(dump_dir, 'metadata.json')) as meta, \
    open(path_join(dump_dir, 'model.proto')) as proto:

    files = {'model': ('model.zip', model, 'application/zip'),
        'metadata': ('metadata.json', meta, 'application/json'),
        'schema': ('model.proto', proto, 'application/text')}

    _post_model(files, push_api, auth_api, 1, max_tries, extra_headers)
