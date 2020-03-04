#Getting the Job Key
DEPLOY_JOB_KEY=`blcli DeployJob getDBKeyByGroupAndName "/User Space/gechegol/Case_00514645" "BLDeploy_Job_Case_00514645"`
echo "DEPLOY_JOB_KEY: $DEPLOY_JOB_KEY"

#Getting the Job ID
JOB_ID=`blcli DeployJobRun findLastRunIdByJobKey $DEPLOY_JOB_KEY`
echo "DEPLOY_JOB_KEY: " $JOB_ID

#Exporting the log
blcli Utility exportDeployRun "/User Space/gechegol/Case_00514645" "BLDeploy_Job_Case_00514645" $JOB_ID "/tmp/Case_00514645/sampleJobResult.csv"