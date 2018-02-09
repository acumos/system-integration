#!/bin/bash

##################################################################################
# This Acumos software file is distributed by AT&T and Tech Mahindra
# under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# This file is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##################################################################################

##################################################################################
# Bootstrapping script to onboard models into a fresh Acumos instance
# Run this after setting up and configuring your Acumos instance to add some models to your catalog. 
#
# File structure:
# bootstrap.sh  -- this file; run to onboard a set of bootstrap models
# properties.sh -- edit this to provide credentials/URLs for your particular Acumos instance
# models/       -- directory containing the models to onboard
#    model1/    -- directory containing model model1
#        model.zip         -- actual model model1 itself
#        metadata.json     -- metadata for model1
#        model.proto       -- protobuf file form model1
#        image.jpg         -- image to use in catalog for model1
#        description.txt   -- descriptive text to use in catalog for model1
#    model2/    -- directory containg model model1
#        ...
#    model3/    -- etc.
#        ....
##################################################################################

# Fetch properties
. properties.sh

echo '**********'
echo -n "Bootstrapping starting up at "; date
echo
echo "Obtaining authentication token for user" $USERNAME
echo

read -r -d '' body<<EOF
{"request_body":
    {
        "username":"$USERNAME",
        "password":"$PASSWORD"
    }
}
EOF

# Query rest service to get token
response=`curl -H 'Content-Type: application/json' -H 'Accept: application/json' -d "$body" $AUTHURL`

# Magic to set status and jwtToken variables from returned json
eval `echo $response | tr -d '"{}' | tr ':,' "=\n"`

# Use this jwtToken for all the bootstrap onboarding
if [ "$status" == "SUCCESS" ]
then
    echo
    echo "Authetication successful"
    echo
    for model in `ls models`
    do
	echo "Onboarding model" $model "..."
	echo "##########################################################################1"
	IP=$(curl -H "Authorization: $jwtToken"\
	     -F "model=@models/$model/model.zip;type=application/zip"\
	     -F "metadata=@models/$model/metadata.json;type=application/json"\
	     -F "schema=@models/$model/model.proto;type=application/text" $PUSHURL |
             sed -e 's/[{}]/''/g' | 
             awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}') 
	echo "$IP  end of response**************"
	echo -n "Onboarding" $model "succeeded at "; date
	echo "###################GettingSolutionId########################################2"
	q1=$(echo $IP  | sed -e 's/[:]/''/g' | awk -v k="text" '{n=split($0,a," "); for (i=1; i<=1; i++) print a[4]}');
        echo "$q1"
        solId=$(echo $q1  | sed -e 's/["solutionId"]/''/g' | awk -v k="text" '{n=split($0,a," "); for (i=1; i<=1; i++) print a[1]}')
        echo "$solId"
        file=./models/$model/description.txt
        desc=`cat $file`
        echo "$desc"
        finaldesc=$(echo $desc)
        curl -i -X POST --header "Content-Type:application/json" --header "Accept:application/json" -d "{\"description\":\"$finaldesc\",\"solutionId\":\"$solId\",\"revisionId\":\"8fc6984b-a5fa-4fd4-b0bb-e549ba6cf172\"}" http://localhost:9080/site/api-manual/Solution/description/public
        echo        
        echo "#############################################################################3"
	echo "Adding image for model" $model "..."
       	curl -i -X POST -F file=@./models/$model/image.jpg http://localhost:9080/site/api-manual/Solution/solutionImages/$solId
       	echo "done adding image"
	echo "Adding descriptitive text for model" $model "..."
	echo "done adding text"
	echo "SOHIL"
	echo -n "All done with model" $model "at "; date
	echo
    done
    else
    echo 'Authentication failed, status = ' $status
    echo 'Cannot continue, exiting'
fi

echo -n "Bootstrapping all finished at "; date
echo '**********'
