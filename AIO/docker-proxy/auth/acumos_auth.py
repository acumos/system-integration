#!/usr/bin/env python
# ===============LICENSE_START=======================================================
# Acumos Apache-2.0
# ===================================================================================
# Copyright (C) 2019 AT&T Intellectual Property. All rights reserved.
# Modifications Copyright (C) 2019 Nordix Foundation.
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
import json
import requests

class JSONObject:
  def __init__(self, d):
    self.__dict__ = d

proxy_host = os.environ['ACUMOS_DOCKER_PROXY_HOST']
proxy_port = os.environ['ACUMOS_DOCKER_PROXY_PORT']
cds_root = os.environ['ACUMOS_CDS_URL']
cds_user = os.environ['ACUMOS_CDS_USER']
cds_pass = os.environ['ACUMOS_CDS_PASSWORD']
api_port = os.environ['ACUMOS_DOCKER_PROXY_AUTH_API_PORT']
api_path = os.environ['ACUMOS_DOCKER_PROXY_AUTH_API_PATH']
auth_url = os.environ['ACUMOS_AUTH_URL']
log_file = os.environ['ACUMOS_DOCKER_PROXY_LOG_FILE']
log_level = os.environ['ACUMOS_DOCKER_PROXY_LOG_LEVEL']
username = None
password = None
jwtToken = {}

#--------------------------------------------------------------------------
# Log event
#--------------------------------------------------------------------------

def log(event):
  print(event)
  logger.debug(event)

#--------------------------------------------------------------------------
# Send API request to CDS
#--------------------------------------------------------------------------

response = None
response_json = None
def cds_request(api_path):
    log("Issuing CDS API request: {0}".format(api_path))
    global solution
    url = '{0}{1}'.format(cds_root,api_path)
    log("Issuing CDS API request: {0}".format(url))
    r = requests.post(url, auth=HTTPBasicAuth(cds_user, cds_pass))
    log('CDS return code {0}'.format(r.status_code))
    if r.status_code != 200:
        log('CDS GET {0} failed, return code {1}'.format(api_path,r.status_code))
        return False
    else:
        response = json.loads(response.text)
        response_json = json.loads(body, object_hook=JSONObject)
        log('Response: \n'
            '{0}'.format(json.dumps(response_json,
            sort_keys=False,
            indent=4,
            separators=(',', ': '))))
        return True

# jobj = json.loads(body)
# domain = jobj['event']['commonEventHeader']['domain']
# e = json.loads(body, object_hook=JSONObject)
# vmid=e.event.measurementsForVfScalingFields.memoryUsageArray[0].vmIdentifier

#--------------------------------------------------------------------------
# Verify user authentication
#--------------------------------------------------------------------------

def verify_basic_auth(b64_credentials):
    log("Verifying basic auth user credentials: {0}".format(b64_credentials))
    global auth_url
    global username
    global password
    global jwtToken
    credentials = b64decode(b64_credentials)
    username, password = credentials.split(':')
    log('Issuing token request for user: {}'.format(username))
    pdata='{{"request_body":{{"username":"{0}","password":"{1}"}}}}'.format(username, password)
    r = requests.post(auth_url, data=pdata, headers={'Content-Type': 'application/json'}, verify=False)
    if r.status_code == 200:
        log('Auth successful for user: {0}'.format(username))
        resp = r.json()
        jwtToken[username] = resp['jwtToken']
        log("Updated jwtToken for {}: {}".format(username, jwtToken[username]))
        return True
    else:
        log('Auth failed for user: {0}'.format(username))
        return False

#--------------------------------------------------------------------------
# Process sub_request from nginx
#--------------------------------------------------------------------------

def listener(environ, start_response):
    '''
    Handler for the Acumos docker-proxy subrequest Auth API.

    Extract basic auth header and verify that the user can be authenticated by
    the Acumos Portal using the supplied credentials.

    '''
    global response
    global response_json
    global solution
    global solution_json
    global revision
    global revision_json
    # Don't include current SCRIPT_NAME (/auth) in the redirect URL
    authok_url = 'https://{}:{}/authok{}'.format(proxy_host,proxy_port,
      environ.get('HTTP_X_ORIGINAL_URI'))

    # Per https://docs.python.org/3/library/wsgiref.html
    log('request_uri: {0} '.format(request_uri(environ, include_query=True)))
    log('authok_url: {0} '.format(authok_url))
    uri = environ.get('HTTP_X_ORIGINAL_URI')
    log('X-Original-URI: {0} '.format(uri))
    log('AUTHORIZATION: {0} '.format(environ.get('HTTP_AUTHORIZATION')))

    # Split the path with max 4 splits
    # /v2/square_5968f2ae-e0d6-46e6-81c1-dc19db3c4965/manifests/2
    if (uri.find('/manifests/') != -1):
        image, resource, version = uri.split('/')[-3:]
        log("image={}, resource={}, version={}".format(image, resource, version))
        log("Splitting image reference: {0}".format(image))
        # Split the solutionId e.g.square_5968f2ae-e0d6-46e6-81c1-dc19db3c4965
        lastIndexOfUnderscore =image.rindex('_');
        name = image[0:lastIndexOfUnderscore]
        solutionId = image[lastIndexOfUnderscore+1:len(image)]
        log("name={}, solutionId={}".format(name, solutionId))

    log("Splitting AUTHORIZATION header")
    mode, b64_credentials = string.split(environ.get('HTTP_AUTHORIZATION',
                                                     'None None'))

    if (b64_credentials == 'None'):
        log("No credentials")
        start_response('401 Unauthenticated', [('WWW-Authenticate','BASIC realm="Sonatype Nexus Repository Manager"')])
        return []
    else:
        log("AUTHORIZATION header details: {0},{1}".format(mode,b64_credentials))
        if (mode == "Basic"):
            if verify_basic_auth(b64_credentials) == False:
                log("Credentials not verified")
                start_response('403 Forbidden', [])
                return []
            else:
                start_response('307 Temporarily Redirect', [('Location',authok_url)])
#                body = {"token": jwtToken[username], "expires_in": 3600}
#                return [json.dumps(body)]
                return []
        elif (mode == "Bearer"):
            log("Bearer token validation/refresh is a TODO!")
            if (image == 'None'):
                log("Credentials verified, base /v2/ request allowed")
                start_response('307 Temporarily Redirect', [('Location',authok_url)])
                return []
            elif (resource == 'blobs'):
                log("Credentials verified, blob request allowed")
                start_response('307 Temporarily Redirect', [('Location',authok_url)])
                return []
            elif cds_request('/solution/{0}'.format(solutionId)):
                solution = response
                solution_json = response_json
                if cds_request('/solution/{0}/revision'.format(solutionId)):
                    for rev in response:
                        revision_json = json.loads(rev, object_hook=JSONObject)
                        if (revision_json.version == version):
                            revision = response
                            if cds_request('/user/search?loginName={0}'.format(username)):
                                if (revision_json.userId == username):
                                    log("User owns revision, allowed")
                                    start_response('307 Temporarily Redirect', [('Location',authok_url)])
                                    return []
                                else:
                                    if (revision.accessTypeCode != 'PR'):
                                        log("Revision is not private, allowed")
                                        start_response('307 Temporarily Redirect', [('Location',authok_url)])
                                        return []
                                    else:
                                        log("Revision is private and not owned by user, denied")
                                        start_response('403 Forbidden', [])
                                        return []
                            else:
                                start_response('500 Internal Server Error', [])
                                return []
                else:
                    start_response('500 Internal Server Error', [])
                    return []
            else:
                start_response('500 Internal Server Error', [])
                return []

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
