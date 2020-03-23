#!/bin/nsh

# Get all running jobs
blcli_execute JobRun showRunningJobs

# Store Variable
blcli_storeenv RUNNINGJOBS

echo "${RUNNINGJOBS}"