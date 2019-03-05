#!/usr/bin/env python
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
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
# What this is: Authentication subrequest handler for the Acumos docker-proxy
#

from wsgiref.simple_server import make_server
from wsgiref.util import request_uri
import sys
import os
import platform
import traceback
import time
import logging.handlers
from base64 import b64decode
import string
from functools import partial
import requests

api_port = os.environ['ACUMOS_DOCKER_PROXY_AUTH_API_PORT']
api_path = os.environ['ACUMOS_DOCKER_PROXY_AUTH_API_PATH']
auth_url = os.environ['ACUMOS_AUTH_URL']
log_file = os.environ['ACUMOS_DOCKER_PROXY_LOG_FILE']
log_level = os.environ['ACUMOS_DOCKER_PROXY_LOG_LEVEL']

def listener(environ, start_response):
    '''
    Handler for the Acumos docker-proxy subrequest Auth API.

    Extract basic auth header and verify that the user can be authenticated by
    the Acumos Portal using the supplied credentials.

    '''
    # Per https://docs.python.org/3/library/wsgiref.html
    print('request_uri: {0} '.format(request_uri(environ, include_query=True)))
    logger.debug('request_uri: {0} '.format(request_uri(environ, include_query=True)))
    print('REQUEST_URI: {0} '.format(environ.get('REQUEST_URI')))
    logger.debug('X-Original-URI: {0} '.format(environ.get('HTTP_X_ORIGINAL_URI')))
    print('X-Original-URI: {0} '.format(environ.get('HTTP_X_ORIGINAL_URI')))

#    ret = ["%s: %s\n" % (key, value)
#           for key, value in environ.iteritems()]
#    return ret

    mode, b64_credentials = string.split(environ.get('HTTP_AUTHORIZATION',
                                                     'None None'))
    if (b64_credentials != 'None'):
        print('Auth header: {0}'.format(environ.get('HTTP_AUTHORIZATION')))
        logger.debug('Auth header: {0}'.format(environ.get('HTTP_AUTHORIZATION')))
        credentials = b64decode(b64_credentials)
        username, password = credentials.split(':')
        logger.debug('auth request from user: {0}'.format(username))
        print('auth request from user: {0}'.format(username))
        pdata='{{"request_body":{{"username":"{}","password":"{}"}}}}'.format(username,password)
        r = requests.post(auth_url, data=pdata, headers={'Content-Type': 'application/json'}, verify=False)
        if r.status_code == 200:
            start_response('200 OK', [])
            print('auth successful for user: {0}'.format(username))
            logger.debug('auth successful for user: {0}'.format(username))
            yield ''
        else:
            print('auth failed for user: {0}'.format(username))
            logger.debug('auth failed for user: {0}'.format(username))
            start_response('401 Unauthorized')
            yield ''
    else:
        start_response('200 OK', [])
        yield ''

def main(argv=None):
    '''
    Main function for the Acumos docker-proxy subrequest Auth API.
    Uses https://wingware.com/psupport/python-manual/2.5/lib/module-wsgiref.simpleserver.html

    The process listens for basic authentication requests and checks them.
    Errors are displayed to stdout and logged, and returned as 401 responses.
    '''
    program_name = os.path.basename(sys.argv[0])

    try:
        global logger
        print('Logfile: {0}'.format(log_file))
        logger = logging.getLogger('acumos')
        if log_level > 0:
            logger.setLevel(logging.DEBUG)
        else:
            logger.setLevel(logging.INFO)
        handler = logging.handlers.RotatingFileHandler(log_file,
                                                       maxBytes=1000000,
                                                       backupCount=10)
        date_format = '%Y-%m-%d %H:%M:%S.%f %z'
        formatter = logging.Formatter('%(asctime)s %(name)s - '
                                      '%(levelname)s - %(message)s',
                                      date_format)
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.info('Started')

        logger.debug('docker-proxy auth port = {0}'.format(api_port))
        logger.debug('docker-proxy auth path = {0}'.format(api_path))
        logger.debug('acumos auth URL = {0}'.format(auth_url))
        logger.debug('log file = {0}'.format(log_file))
        logger.debug('log level = {0}'.format(log_level))

        httpd = make_server('', int(api_port), listener)
        print('Serving on port {0}...'.format(api_port))
        httpd.serve_forever()

        logger.error('Main loop exited unexpectedly!')
        return 0

    except KeyboardInterrupt:
        logger.info('Exiting on keyboard interrupt!')
        return 0

    except Exception as e:
        indent = len(program_name) * ' '
        sys.stderr.write(program_name + ': ' + repr(e) + '\n')
        sys.stderr.write(indent + '  for help use --help\n')
        sys.stderr.write(traceback.format_exc())
        logger.critical('Exiting because of exception: {0}'.format(e))
        logger.critical(traceback.format_exc())
        return 2

if __name__ == '__main__':
    sys.exit(main())
