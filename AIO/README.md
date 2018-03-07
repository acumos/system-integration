# All In One for Acumos 

These scripts build an all-in-one instance of Acumos, with the database,
Nexus repositories and docker containers all running on a single virtual machine.

## Contents

* oneclick_deploy.sh: the script you will run as “bash oneclick_deploy.sh”.
* acumos-env.sh: environment setup script that will get customized as new env parameters get generated (e.g. passwords). Used by oneclick_deploy.sh and clean.sh. You can get the mysql root and user passwords from this if you want to do any manual database operations, e.g. see what tables/rows are created.
* clean.sh: script you can run as “bash clean.sh” to remove the Acumos install, to try it again etc.
* cmn-data-svc-ddl-dml-mysql-1.13.sql: Common Dataservice database setup script. Used by oneclick_deploy.sh.
* docker-compose.sh: Script called by the other scripts as needed, to take action on the set of Acumos docker services. Used by oneclick_deploy.sh and clean.sh. You can also call this directly e.g. to tail the service container logs. See the script for details.
* docker-compose.yaml: The docker services that will be acted upon, per the options passed to docker-compose.sh.

## License

Copyright (C) 2017 AT&T Intellectual Property & Tech Mahindra. All rights reserved.
Acumos is distributed by AT&T and Tech Mahindra under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License. You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either 
express or implied.  See the License for the specific language governing permissions and limitations 
under the License.
