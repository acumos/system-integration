#usage ./all-start-stop.sh create/delete
for i in *; do ./acumos-volumeclaim.sh $i $1; done > /dev/null 2>&1