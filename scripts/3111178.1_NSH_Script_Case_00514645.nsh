#Getting Parametters
JOB_GROUP=$1
JOB_NAME=$2
PATH_TO_EXPORT=$3
EXPORT_FILE_NAME=$4
PATH_AND_FILE=$PATH_TO_EXPORT"/"$EXPORT_FILE_NAME
#JOB_FULL_PATH=$JOB_GROUP"/"$JOB_NAME


echo "--------------Parameters---------------"
echo "JOB_GROUP: " $JOB_GROUP
echo "JOB_NAME: " $JOB_NAME
echo "PATH_TO_EXPORT: " $PATH_TO_EXPORT
echo "EXPORT_FILE_NAME: " $EXPORT_FILE_NAME
echo "PATH_AND_FILE: " $PATH_AND_FILE

#Validate the parameters are not empty
#If you want you can validate that parameters are not empty and throw an exception

#Getting the Job Key
DEPLOY_JOB_KEY=`blcli DeployJob getDBKeyByGroupAndName "$JOB_GROUP" "$JOB_NAME"`

echo "--------------JobKey---------------"
echo "DEPLOY_JOB_KEY: $DEPLOY_JOB_KEY"

#Getting the Job ID
JOB_ID=`blcli DeployJobRun findLastRunIdByJobKey $DEPLOY_JOB_KEY`
echo "DEPLOY_JOB_KEY: " $JOB_ID

#Exporting the log
blcli Utility exportDeployRun "$JOB_GROUP" "$JOB_NAME" "$JOB_ID" "$PATH_AND_FILE"
