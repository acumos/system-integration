# Jenkins Jobs for Acumos

This area has templates for creating Jenkins jobs using the Jenkins Job Builder (https://docs.openstack.org/infra/jenkins-job-builder/index.html).
All templates are in the "jjb" folder.  Invoke the tool to recurse into that folder and process all templates (YAML files).

Quickstart guide:

0. Install the tool:

    pip install --user jenkins-job-builder

1. Test the templates in the jjb folder:

    jenkins-jobs --conf conf-jjb.ini test jjb

2. Generate templates and update the Jenkins instance:

    jenkins-jobs --conf conf-jjb.ini --user jenkins-user --password jenkins-pass update jjb
