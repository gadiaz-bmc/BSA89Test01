#title           :Action_Block_7.nsh
#description     :Action handler for BSA Remediation jobs bundling
#				 :
#author		 	 :Mateusz Pieta (a585208)
#date            :19.04.2019
#version         :1.0    
#usage		 	 :Action_Block_7.nsh

#==============================================================================

cd "${0%/*}"
#debug=true
#blcli_setoption serviceProfileName UAT
#if [ ! -d tmp ]; then mkdir tmp ; fi
TimeStamp=$(awk 'BEGIN {srand(); print srand()}')

JobID="40045"
JobRunID=""
Include=""
Exclude=""
SNMP="127.0.0.1"
simulateType="NotScheduled"
stageType="NotScheduled"
commitType="NotScheduled"
simulateDateString=""
stageDateString=""
commitDateString=""
isStagedIndirect="false"
AllowReboot="false"
PreCmd=""
PostCmd=""
servers=""
ActionName=""
Role=""

function RebootOption()
{
case "${@}" in 
	"Reboot") RebootSetting=3 ;;
	"NoReboot") RebootSetting=1 ;;
	"Default") RebootSetting=0 ;;
	*) print_error "reboot option: ${OPTARG} not recognized" ;;
esac
}

function print_error()
{
   echo -E "${@}"
   exit 1
}

function print_info()
{
	xml_result="${xml_result}${@}"
    return 0

}

function print_xml()
{
    echo -ne "${xml_result}"    
    return 0

}
function print_debug()
{

    if [ "$debug" = "true" ] ; then
		echo "[$(date)] [DEBUG] ${@}\r\n"
	fi

    return 0

}

while getopts "i:e:s:d:t:y:c:o:p:a:f:g:j:k:l:b:r:" arg; do
  case $arg in
    i)
      Include="$OPTARG"
      ;;
    e)
      Exclude="$OPTARG"
      ;;
    s)
      simulateType="$OPTARG"
      ;;
    d)
      simulateDateString="$OPTARG"
      ;;
    t)
      stageType="$OPTARG"
      ;;
    y)
      stageDateString="$OPTARG"
      ;;
    c)
      commitType="$OPTARG"
      ;;
    o)
      commitDateString="$OPTARG"
      ;;
    p)
      isStagedIndirect="${OPTARG:l}"
      ;;
    a)
      RebootOption "$OPTARG"
      ;;
    f)
      PreCmd="$OPTARG"
      ;;
    g)
      PostCmd="$OPTARG"
      ;;
    j)
      servers="$OPTARG"
      ;;
    k)
      JobID="$OPTARG"
      ;;
    l)
      SNMP="${OPTARG:l}"
      ;;
    b)
      ActionName="$OPTARG"
      ;;
    r)
      Role="$OPTARG"
      ;;

  esac
done


run_blcli_cmd()
{

        unsetopt multios
        local varName="${1}"
        local errOnFail="${2}"
        local silent="-Dcom.bladelogic.cli.execute.quietmode.enabled=true"
        local RETCODE
        local tmpRESULT
        local RESULT

        if [[ -n ${BLCLICMD[@]} ]]
        then
                holder=$(echo $RANDOM)
                print_debug "blcli_execute ${BLCLICMD[@]}"
                blcli_execute "${BLCLICMD[@]}" &>tmpERROR_${holder}
                RETCODE=$?
                error=$(tail -1 tmpERROR_${holder})
                rm tmpERROR_${holder}
                if [[ $RETCODE -eq 0 ]]; then
                        blcli_storeenv tmpRESULT &>tmpRESULT
                        #echo "${tmpRESULT}"
                        # storeenv exports the variable, we want to keep it local
                        RESULT="${tmpRESULT}"
                        unset tmpRESULT
                        if [[ "${BLCLICMD[2]}" = "executeSqlCommand" ]]; then
                                rowNames="$(grep -e '<Row' -e '<Name>' <<< "${RESULT}" | sed "s/<Name>//g;s/<\/Name>/,/g;s/<Row.*/BEGIN/g;s/^[[:space:]]*//g" | awk '/BEGIN/{if (NR!=1)print "";next}{printf $0}END{print "";}' | sed "s/,$//g" | sort -u)"
                                resultRows="$(grep "numberOfRows" <<< "${RESULT}"| cut -f2 -d= | sed "s/>//g;s/\"//g")"
                                RESULT="$(grep -e Value -e '<Row' <<< "${RESULT}"  | sed "s/<Value>//g;s/<\/Value>/,/g;s/<Row.*/BEGIN/g;s/^[[:space:]]*//g" | awk '/BEGIN/ {if (NR!=1)print "";next}{printf $0}END{print "";}' | sed "s/,$//g")"
                        fi
                        if [[ "${#RESULT}" -lt 256 ]]; then
                                print_debug "${RESULT//[[:cntrl:]]/ }"
                                # set RESULT to the variable we passed in
                        else
                                print_debug "blcli RESULT longer than 256 characters, skipping for readablity..."
                        fi
            if [[ "${varName}x" != "x" ]]; then
                                eval ${varName}="$(printf '%q' "${RESULT}")" 2>&1
                        fi
                        if [[ "${errOnFail}x" != "x" ]]; then
                                blcliOut="pass"
                        fi
                        return $RETCODE
                else
                        if [[ "${varName}x" != "x" ]]; then
                                eval ${varName}="$(printf '%q' "${RESULT}")"
                        fi
						
                        print_error "${BLCLICMD[@]} : ${error#Command*:}"
                        

                        if [[ "${error}" = *"No NSH script parameter exists with name"* ]] ; then
                                print_error 2 "${error#Command*:}"
                        else
                                print_error 1 "${error#Command*:}"
                        fi
                fi
        else
                print_error 1 "No BLCLI command supplied!"
                return 999
        fi
}

BLCLICMD=(Job getLastJobDBKeyByJobId ${JobID})
run_blcli_cmd PatchingJobDBKey
BLCLICMD=(Job getName)
run_blcli_cmd JobName


if [ -z "$Role" ]; then
	
	BLCLICMD=(Job getPropertyValueAsString "_CUSTOMER")
	run_blcli_cmd Customer
	
	#Determine Job OS
	BLCLICMD=(PatchingJob getAnalysisJob)
	run_blcli_cmd JobOS

	case "${JobOS:u}" in
      	  *"REDHAT"*)		JobOS="Linux" ; System="L" ;;
      	  *"WINDOWS"*)		JobOS="Windows" ; System="W" ;;
	esac

	Role="${Customer/_*/}_L3Admin${System}"
	Customer=${Customer/_*/}

else
	Customer=${Role/_*/}
fi



if [[ -z $JobRunID ]] ; then
	BLCLICMD=(JobRun findLastRunKeyByJobKeyIgnoreVersion "${PatchingJobDBKey}")
	run_blcli_cmd PatchingJobRunKey
	BLCLICMD=(JobRun getJobRunId)
	run_blcli_cmd JobRunID
else
	BLCLICMD=(JobRun findRunKeyById "${JobRunID}")
	run_blcli_cmd PatchingJobRunKey
	BLCLICMD=(JobRun getJobRunId)
	run_blcli_cmd JobRunID
fi

BLCLICMD=(JobRun findPatchingJobChildrenJobsByRunKey "${JobRunID}")
run_blcli_cmd
BLCLICMD=(JobRun getJobRunId)
run_blcli_cmd
BLCLICMD=(Utility setTargetObject)
run_blcli_cmd 
BLCLICMD=(Utility listPrint)
run_blcli_cmd childRunIDs

for ChildRunID in $childRunIDs ; do 
	BLCLICMD=(JobRun findById $ChildRunID)
	run_blcli_cmd 
	BLCLICMD=(JobRun getType)
	run_blcli_cmd ChildTypeID
	if [ "$ChildTypeID" -gt 7020 ] && [ "$ChildTypeID" -lt 7026 ] ; then 
		BLCLICMD=(JobRun getJobType)
		run_blcli_cmd analysisJobTypeId
		BLCLICMD=(JobRun getJobRunKey)
		run_blcli_cmd analysisJobRunKey
	fi
done	
		
#Prepare Groups for particular run

DepotGroupPath="/${Customer}/SDCToBMC/${Role}/IntegrationEngine/PatchManagement"
JobGroupPath="/${Customer}/SDCToBMC/${Role}/IntegrationEngine/PatchManagement"

if [ -z "$ActionName" ]; then
	ActionName="Bundling"
fi

BLCLICMD=(JobGroup groupExists "${JobGroupPath}/${ActionName}")
run_blcli_cmd groupExists

if [ "$groupExists" = "false" ]; then
	BLCLICMD=(JobGroup createGroupWithParentName "${ActionName}" "${JobGroupPath}")
	run_blcli_cmd 
fi

BLCLICMD=(DepotGroup groupExists "${DepotGroupPath}/${ActionName}") ;
run_blcli_cmd groupExists ;

if [ "$groupExists" = "false" ]; then
	BLCLICMD=(DepotGroup createGroupWithParentName "${ActionName}" "${DepotGroupPath}")
	run_blcli_cmd 
fi

BLCLICMD=(JobGroup createGroupWithParentName "${TimeStamp}" "${JobGroupPath}/${ActionName}")
run_blcli_cmd JobGroupBundlingTargetID
BLCLICMD=(DepotGroup createGroupWithParentName "${TimeStamp}" "${DepotGroupPath}/${ActionName}")
run_blcli_cmd DepotGroupBundlingTargetID
BLCLICMD=(JobGroup createGroupWithParentName "Template" "${JobGroupPath}/${ActionName}/${TimeStamp}")
run_blcli_cmd JobGroupBundlingTemplateID
BLCLICMD=(DepotGroup createGroupWithParentName "Template" "${DepotGroupPath}/${ActionName}/${TimeStamp}")
run_blcli_cmd DepotGroupBundlingTemplateID

BLCLICMD=(JobGroup groupNameToId "${JobGroupPath}/${ActionName}/${TimeStamp}")
run_blcli_cmd pkgJobGroupId
BLCLICMD=(DepotGroup groupNameToId "${DepotGroupPath}/${ActionName}/${TimeStamp}")
run_blcli_cmd pkgDepGroupId

#Prepare remediation option templates

BLCLICMD=(BlPackage createEmptyBlPackage "${TimeStamp}_template" "SDC Patching Template" "${DepotGroupBundlingTemplateID}")
run_blcli_cmd
BLCLICMD=(BlPackage getDBKey)
run_blcli_cmd BLPackageKey
BLCLICMD=(DeployJob createDeployJobWithoutTarget "${TimeStamp}_template" $JobGroupBundlingTemplateID $BLPackageKey true true $isStagedIndirect)
run_blcli_cmd

BLCLICMD=(DeployJob findByGroupAndName "${JobGroupPath}/${ActionName}/${TimeStamp}/Template" "${TimeStamp}_template")
run_blcli_cmd DeployJob
BLCLICMD=(Utility storeTargetObject DeployJob)
run_blcli_cmd
BLCLICMD=(DeployJob setDeployType 1)
run_blcli_cmd
BLCLICMD=(DeployJob setPreCmd "$PreCmd")
run_blcli_cmd
BLCLICMD=(DeployJob setPostCmd "$PostCmd")
run_blcli_cmd
BLCLICMD=(DeployJob setStagingIndirect "$isStagedIndirect")		
run_blcli_cmd		
BLCLICMD=(DeployJob setSingleDeployMode true)		
run_blcli_cmd
BLCLICMD=(DeployJob setRebootSetting "$RebootSetting")
run_blcli_cmd
BLCLICMD=(DeployJob setScheduleType 2)
run_blcli_cmd
BLCLICMD=(DeployJob setExecuteByPhase false)
run_blcli_cmd
BLCLICMD=(Job update NAMED_OBJECT=DeployJob)
run_blcli_cmd 

#Create and run remediation job to generate deploys and blpackages
BLCLICMD=(PatchRemediationJob createInstance "${TimeStamp}" "SDC Automation")
run_blcli_cmd
BLCLICMD=(Utility storeTargetObject job) 
run_blcli_cmd
BLCLICMD=(PatchRemediationJob setGroupId "${pkgJobGroupId}")
run_blcli_cmd
BLCLICMD=(PatchRemediationJob setDeployJobGroupId "${pkgJobGroupId}")
run_blcli_cmd
BLCLICMD=(PatchRemediationJob setPackageGroupId "${pkgDepGroupId}")
run_blcli_cmd
BLCLICMD=(PatchRemediationJob setPackagePrefix "${TimeStamp}")
run_blcli_cmd
BLCLICMD=(PatchRemediationJob setAnalysisJobRunDetails "${analysisJobTypeId}" "${analysisJobRunKey}")
run_blcli_cmd
BLCLICMD=(PatchRemediationJob setPackageSoftLinked true)
run_blcli_cmd

#Remediate set of servers only if provided.
OLDIFS=$IFS
IFS=','
if [ -n "$servers" ] ; then
	for server in $servers
	do
		if [ -n "$Include" ] ; then
			for patch in $Include
			do
				BLCLICMD=(PatchRemediationJob addPatch $server $patch $PRJ)
				run_blcli_cmd
			done
		else
			BLCLICMD=(PatchRemediationJob addServer $server)
			run_blcli_cmd
		fi
		
	done
else
	if [ -n "$Include" ] ; then
		for patch in $Include
		do
			BLCLICMD=(PatchRemediationJob addPatch $patch)
			run_blcli_cmd
		done
	fi
fi
IFS=$OLDIFS

BLCLICMD=(Job create NAMED_OBJECT=job)
run_blcli_cmd
BLCLICMD=(Job getDBKey)
run_blcli_cmd PatchRemediationJobKey
BLCLICMD=(PatchRemediationJob copyDeployJobOptions NAMED_OBJECT=DeployJob)
run_blcli_cmd
BLCLICMD=(Job update NAMED_OBJECT=job)
run_blcli_cmd 
BLCLICMD=(PatchRemediationJob getDeployJobTemplate)
run_blcli_cmd
BLCLICMD=(Utility setTargetObject)
run_blcli_cmd
BLCLICMD=(DeployJobTemplate setDeployJobScheduleForAdvancePhaseExecution "$simulateType" "$simulateDateString" "$stageType" "$stageDateString" "$commitType" "$commitDateString")
run_blcli_cmd

BLCLICMD=(PatchRemediationJob executeJobAndWait "${PatchRemediationJobKey}")
run_blcli_cmd PatchRemediationJobRunKey

#Wait for Remediation to complete
BLCLICMD=(JobRun getJobRunIsRunningByRunKey ${PatchRemediationJobRunKey})
run_blcli_cmd IS_JOB_RUN
while ${IS_JOB_RUN}; do
	BLCLICMD=(JobRun getJobRunIsRunningByRunKey ${PatchRemediationJobRunKey})
	run_blcli_cmd IS_JOB_RUN
done
    
#Look for errors
BLCLICMD=(JobRun getJobRunHadWarnings ${PatchRemediationJobRunKey})
run_blcli_cmd HAD_ERROR
BLCLICMD=(JobRun getJobRunHadErrors ${PatchRemediationJobRunKey})
run_blcli_cmd HAD_WARNINGS
if $HAD_ERROR || $HAD_WARNINGS; then
	print_error "Error generating deployjobs with remediation jobRunKey:${PatchRemediationJobRunKey}"
fi  

BLCLICMD=(Job findAllByGroupId "${JobGroupBundlingTargetID}" "false")
run_blcli_cmd 
BLCLICMD=(Job getDBKey)
run_blcli_cmd JobsDBKey
print_info "<DeployJobs>"
for JobDBKey in $(echo ${JobsDBKey} | tr -d '[],')
do  
	BLCLICMD=(Job findByDBKey ${JobDBKey})
	run_blcli_cmd
	BLCLICMD=(Job getType)
	run_blcli_cmd JOB_TYPE_ID   
	if [[ ${JOB_TYPE_ID} = 30 ]] ; then
		BLCLICMD=(Job getJobId)
		run_blcli_cmd DeployJobId
		BLCLICMD=(Job getName)
		run_blcli_cmd DeployJobName
		BLCLICMD=(Job listTargetServers ${JobDBKey} "DECOMMISSIONED,ENROLLED,NOT-ENROLLED")
		run_blcli_cmd JobServerList
						print_info "<DeployJob>"
						print_info "<Id>${DeployJobId}</Id>"
						print_info "<Name>${DeployJobName}</Name>"
						print_info "<Targets>"
		for JobServer in ${JobServerList}
		do					
					BLCLICMD=(Server getServerIdByName $JobServer)
					run_blcli_cmd JobServerId
					print_info "<Target>"
					print_info "<Id>$JobServerId</Id>"
					print_info "<Name>$JobServer</Name>"
					print_info "</Target>"

		done
		print_info "</Targets></DeployJob>"
	fi
done
print_info "</DeployJobs>"
if [ "$JobID" = "2983015" ]; then
print_error "test for job id 2983015"
fi
print_xml
