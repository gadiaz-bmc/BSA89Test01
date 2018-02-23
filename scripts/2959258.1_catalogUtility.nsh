#!/bin/nsh
# vim:syntax=sh
#******************************************************************************
# File Name: catalogUtility.nsh   
#
# Disclaimer:
# ==========
#   THIS SOFTWARE IS PROVIDED BY BMC Software, INC. "AS IS" AND ANY EXPRESS
#   OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED.  IN NO EVENT SHALL BMC, INC. BE LIABLE FOR ANY
#   DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#   DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#   OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#   LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#   OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.
#
# Description:
# ===========
# This script provides a set of actions to perform on patch catalogs 
# that I've found useful over the past.
#
# Parameters:
# ==========
#
#
# Exit Codes:
# ========== 
#
# 
# Revision History:
# ================
# Version  Date         By                 Description
# -------+------------+------------------+-------------------------------------
#  v1.0    05-MAR-2012	Bill Robinson		Initial Creation
#  v1.1    19-ARP-2012  Bill Robinson		Added a list function and more input error checking
#******************************************************************************
 
#set -x			# Un-comment this to get traces of every command
 
###################
# GLOBAL VARIABLES
###################
 
###############
# When Running a script under a solaris appserver, uncomment the following section
#
#if test -z "$BLCLI_FIRST_TIME"
#	then
#	LD_LIBRARY_PATH=`cat /usr/lib/rsc/HOME`/lib
#	export LD_LIBRARY_PATH
#	BLCLI_FIRST_TIME=false
#	export BLCLI_FIRST_TIME
#	exec nsh $0 "$@"
#fi
###############
 
#####
# Rather than using a simple True/False for debug, setting a debug level
# allows us to switch on varying levels of debug, depending on what we're
# trying to achieve.
# This can be used just like the regular DEBUG flag by choosing just to use
# 0 and 1, but optionally, we can have further/different debug levels and
# hence further print_debug1 commands (see below).
# The idea here is to use levels 1-5 for debug and 0 for none.
DEBUGLEVEL=0
 
RESULT="Not Yet Set!"	# Just in case we forget...! ;)
 
# These next 2 values are only used when running from the command line
roleName="BLAdmins"
authProfile="defaultProfile"
 
###################
# PRINT FUNCTIONS
###################
 
print_info()
{
	print "[`date`] [INFO] ${@}"
}
 
print_error()
{
	print -u2 "[`date`] [ERROR] $@"
	exit 1
}
 
print_warn()
{
	print "[`date`] [WARN] $@"
}
 
print_debug1()
{
	[ "${DEBUGLEVEL}" -ge "1" ] && print "[`date`] [DEBUG1] $@"
}

print_debug2()
{
	[ "${DEBUGLEVEL}" -ge "2" ] && print "[`date`] [DEBUG2] $@"
}
 
print_debug3()
{
	[ "${DEBUGLEVEL}" -ge "3" ] && print "[`date`] [DEBUG3] $@"
}
 
print_debug4()
{
	[ "${DEBUGLEVEL}" -ge "4" ] && print "[`date`] [DEBUG4] $@"
}
 
print_debug5()
{
	[ "${DEBUGLEVEL}" -ge "5" ] && print "[`date`] [DEBUG5] $@"
}
 
print_reult()
{
	print "    RESULT: $@"
}

###################
# BLCLI FUNCTIONS
###################
 
#####
# Establishes a connection to BladeLogic in preparation for using the 
# BLCLI Performance Commands.
openBLConnection()
{
	blcli_setjvmoption -Xmx768M
	blcli_setjvmoption -XX:MaxPermSize=192m
	blcli_disconnect 2> ${NULL}
	
	# CLI_INTERACTIVE gets set to false when a script runs from 
	# within BladeLogic.  So when it's NOT false, we must be running
	# from the command line and hence need to take a few extra steps
	# before trying to establish a BLCLI connection.
	# Note that we still need to have cached session credentials for
	# this to work!
	if [ "${CLI_INTERACTIVE}" != "false" ]
	then
		blcli_setoption authType BLSSO
		blcli_setoption serviceProfileName ${authProfile}
		blcli_setoption roleName "${roleName}"
	fi
 
	print_info "Opening connection to BladeLogic"
	blcli_connect && RESULT="OK"
}

closeBLConnection()
{
	print_info "Closing connection to BladeLogic"
	blcli_destroy && RESULT="OK"
}

#####
# Simple function to execute a blcli command using the performance commands
# Output is stored in the environment variable RESPONSE
# Arguments:
#   $BLCLICMD must be set prior to calling this function!
# Returns:
#   0   Success
# 999   No BLCLI supplied
# Other [As returned by BLCLI call]
runBlcliCmd()
{
	print_debug2 "Entering function: ${0}..."
	local varName="${1}" 
	local errOnFail="${2}"

	if [ -n ${BLCLICMD[@]} ]
	then
		print_debug3 "blcli_execute ${BLCLICMD[@]}"
		blcli_execute "${BLCLICMD[@]}" > ${BLCLIOUT} 2> ${BLCLIERR}
		RETCODE=$?
 		if [ $RETCODE -eq 0 ] 
			then
			blcli_storeenv RESULT
			if [ ${#RESULT} -gt 250 ]  
				then
				RESULT="blcli result too long, not outputting..."
			fi
			print_debug3 "blcli result: `echo ${RESULT} | tr -d '[:cntrl:]'`"
			# set RESULT to the variable we passed in
            if [ "${varName}x" != "x" ]
              	then
				blcli_storeenv ${varName} > ${NULL}
			fi

			if [ "${errOnFail}x" != "x" ]
				then
				blcliOut="pass"
			fi
			return $RETCODE
		else
			if [ "${errOnFail}x" = "x" ]
				then
				RESULT=`cat ${BLCLIERR} | cut -f2- -d:`
				print_error "${RESULT}"
			else
				blcliOut="fail"
			fi
		fi
	else
		print_error "No BLCLI command supplied!"
		return 999
	fi
	print_debug2 "Exiting function: ${0}..."
}

###################
# UTILITY FUNCTIONS
###################
 
#####
# Generic Usage command
# TO-DO: Customise on a "per script" basis
#
# Arguments:				
#   $1   Required exit code - defaults to 1.
#
usage()
{
	if [ "${1}" = "" ]
	then
		USAGE_CODE=1
	else
		USAGE_CODE=${1}
	fi
	echo "This script manipulates Patch Catalogs and Objects they contain.  There are multiple modes this can operate in, and this can be the basis"
	echo "for user-defined actions:"
	echo "setCUJProperty - sets a property value on the Catalog Update Jobs:"
	echo "  example: nsh ${SCRIPT_NAME} -m setCUJProperty -p JOB_TIMEOUT -b 600"
	echo "setCatalogObjectProperty - sets a property based on some criteria on each object in the catalog,"
	echo "  eg, if the QNumber matches a list, set IS_APPROVED to true.  This subroutine should be customized"
	echo "  to match exactly what you need to do."
	echo "  example: nsh ${SCRIPT_NAME} -m setCatalogObjectProperty -p QNUMBER -q IS_APPROVED"
	echo "setPayloadLocation - this updates the depot object location in the event you need to move the catalog, or"
	echo "  you need to change the payload URL type from say AGENT_COPY_AT_STAGING to AGENT_MOUNT"
	echo "  example: nsh ${SCRIPT_NAME} -m setPayloadLocation -u //reposerver1/mnt/repo/redhat5 -t AGNET_COPY_AT_STAGING "
	echo "deleteCatalogObjects - deletes all objects in the catalog"
	echo "  example: nsh ${SCRIPT_NAME} -m deleteCatalogObjects"
	echo "setACLPolicy - sets the ACLPolicy on existing objects in the catalog, and removes any existing ACLPolicies"
	echo "  example: nsh ${SCRIPT_NAME} -m setACLPolicy -a NewPolicy"
	echo "listAllCatalogPaths - dumps the paths for all catalogs"
	echo ""
	echo "The -e option will let you specify the catalog type so the script will run against all catalogs of that type,"
	echo " and it's required w/ the -c option"
	echo " example: nsh ${SCRIPT_NAME} -m deleteCatalogObjects -e WINDOWS_CATALOG_GROUP"
	echo "The -c option will let you specify a specific catalog to act on, and you must identify the type w/ -e"
	echo " example: nsh ${SCRIPT_NAME} -m deleteCatalogObjects -e WINDOWS_CATALOG_GROUP -c \"/Patch Catalogs/Windows\""
	echo ""
	echo "Usage: $0 -d <level> -m <scriptMode> <args>"
	echo "-d	<debug level>		Debug Log output, level 0-5.  Should be first option (int)"
	echo "-m	<scriptMode>        Mode of the script from above"
	echo "-e	<catalogType> 		Catalog type to run against"
	echo "-s	<dryRun>       		Do this as a dry run and don't change anything (true/false)"
	echo "-c	<catalogPath>		Individual Catalog, must use -e"
	echo "-p	<propertyName>		Property Name, for use w/ setCUJProperty and setCatalogObjectProperty"
	echo "-b	<propertyValue>		Property Value, for use w/ setCUJProperty"
	echo "-q 	<propertyName>		The second Property Name, for use w/ setCatalogObjectProperty"
	echo "-f 	<mapfile>			A file to read a property mapping out of, for use w/ setCatalogObjectProperty"
	echo "-t 	<URLType>			Payload URL Type, for use with setPayloadLocation"
	echo "-e 	<newURL>			New location to the patch object, for use with setPayloadLocation"
	echo "-a	<aclPolicy>   		Name of the new ACLPolicy to apply, for use with setACLPolicy"
	echo ""
			
	exit $USAGE_CODE
}

#####
# In various situations we need to pipe the output of certain commands to
# NULL.  Since this differs depending on the system on which the script is
# being run, we set it dynamically here.
setNull()
{
	# By piping the output of uname into grep, we don't rely on hard-coding
	# 'WindowsNT' as the system name, just in case Misrosoft change it in
	# the future.  Hopefully, whatever they use will still modify with 
	# 'Windows'...!
	uname -s | grep -q "^Windows"
	if [ $? -eq 0 ]
	then
		print_debug5 "Setting NULL for a Windows platform"
		NULL="NUL"
	else
		print_debug5 "Setting NULL for a UNIX platform"
		NULL="/dev/null"
	fi
}

#####
# Temp File functions
initTmpFile()
{
	! [ -d "${TMPDIR}" ] && mkdir -p "${TMPDIR}"
}

removeTmpFile()
{
	[ -d "${TMPDIR}" ] && [ "${TMPDIR}" != "/" ] && rm -rf "${TMPDIR}"
}
 
#####
# This function initialises the environment and MUST be called at the modify
# of the main code!
initScript()
{
	setNull
	[ ${#@} -eq 0 ] && usage
	processParameters "$@"
	initTmpFile
	openBLConnection
}
 
#####
# This function closes down, disconnects and generally cleans up the environment
# at the end of execution and should be called at the end of the main code.
cleanupEnv()
{
	if [ "${cleanupFiles}" = "true" ]
		then
		print_debug1 "Cleaning up temporary files in ${TMPDIR}..."
		removeTmpFile
	else
		print_warn "Not cleaning up temporary files in ${TMPDIR}..."
	fi
	closeBLConnection

}

#####
# All parameters should be handled in this function.
# TO-DO: Add in custom parameters for each script
processParameters()
{
	while getopts d:p:a:q:f:s:m:t:u:c:e:b: Option
	do
		case "${Option}" in
			d) DEBUGLEVEL="${OPTARG}"
			;;
			c) catalogPath="${OPTARG}"
			   print_debug2 "catalogPath=${catalogPath}"
		    ;;
			e) catalogType="${OPTARG}"
			   print_debug2 "catalogType=${catalogType}"
			;;
			p) propName1="${OPTARG}"
			   print_debug2 "propName1=${propName1}"
			;;
			b) propVal1="${OPTARG}"
			   print_debug2 "propVal1=${propVal1}"
			;;
			q) propName2="${OPTARG}"
			   print_debug2 "propName2=${propName2}"
			;;
			f) mapFile="${OPTARG}"
			   print_debug2 "mapFile=${mapFile}"
			;;
			s) dryRun="${OPTARG}"
			   print_debug2 "dryRun=${dryRun}"
			;;
			m) scriptMode="${OPTARG}"
			   print_debug2 "scriptMode=${scriptMode}"
			;;
			t) newURLType="${OPTARG}"
			   print_debug2 "newURLType=${newURLType}"
			;;
			u) newURL="${OPTARG}"
			   print_debug2 "newURL=${newURL}"
			;;
			a) aclPolicy="${OPTARG}"
			   print_debug2 "aclPolicy=${aclPolicy}"
			;;
			*) usage
			;;
		esac
	done
 
	checkInput
	
	
}

#####################################################################
# MAIN CODE
#####################################################################

#####
# Modify of custom code
#####
#

checkInput()
{

	[ "${DEBUGLEVEL}" -le "0" ] && DEBUGLEVEL=0
	[ "${DEBUGLEVEL}" -gt "5" ] && DEBUGLEVEL=5
	[ "${DEBUGLEVEL}" -gt "0" ] && print_info "Running at Debug level ${DEBUGLEVEL}"
	[ "${DEBUGLEVEL}" -ge "6" ] && set -x

	[ "${scriptMode}x" = "x" ] && print_error "Must specify a scriptMode (-m)"
	[ "${catalogPath}x" != "x" ] && [ "${catalogType}x" = "x" ] && print_error "Must specify a catalog type (-e) that matches the catalog \"${catalogPath}\"..."
	
	if [ "${scriptMode}" = "setCUJProperty" ]
		then
		[ "${propName1}x" = "x" ] && print_error "Must pass a property name (-p) for ${scriptMode}..."
		[ "${propVal1}x" = "x" ] && print_error "Must pass a property value (-b) for ${scriptMode}..."
		[ "${catalogPath}x" != "x" ] && print_error "Really, you need a script to set a property on a single catalog job?..."
	elif [ "${scriptMode}" = "setCatalogObjectProperty" ]
		then
		[ "${propName1}x" = "x" ] && print_error "Must pass a property name (-p) for ${scriptMode}..."
		[ "${propName2}x" = "x" ] && print_error "Must pass a property name (-q) for ${scriptMode}..."
	elif [ "${scriptMode}" = "setPayloadLocation" ]
		then
		[ "${newURLType}x" = "x" ] && print_error "Must pass a new URL type (-t) for ${scriptMode}..."
		[ "${newURL}x" = "x" ] && print_error "Must pass a new URL (-u) for ${scriptMode}..."
		[ "${catalogPath}x" = "x" ] && print_error "Must pass a Catalog Path (-c)..."
		[ "${catalogType}x" = "x" ] && print_error "Must pass a Catalog Type (-e)..."
		if [ "${newURLType}" != "AGENT_COPY_AT_STAGING" ] && [ "${newURLType}" != "AGENT_MOUNT" ]
			then
			print_warn "The newURLType (-t) must be either AGENT_COPY_AT_STAGING or AGENT_MOUNT"
			print_error "and you entered ${newURLType}.."
		fi
	elif [ "${scriptMode}" = "setACLPolicy" ]
		then
		[ "${aclPolicy}x" = "x" ] && print_error "Must pass an ACL Policy (-a) for ${scriptMode}..."
	elif [ "${scriptMode}" = "deleteCatalogObjects" ] || [ "${scriptMode}" = "verifyObjects" ] || [ "${scriptMode}" = "listAllCatalogPaths" ]
		then
		print_debug3 "${scriptMode}"
	else
		print_error "${scriptMode} not recognized.."
	fi
}

getBladeLogicVersion()
{
	print_debug2 "Entering function: ${0}..."
	
	BLCLICMD=(Util getSystemProperty DatabaseVersion true)
	runBlcliCmd bladeVersion
	print_debug2 "Exiting function: ${0}..."
}

findAllCatalogJobs()
{
	print_debug2 "Entering function: ${0}..."
	local count=1
	
	# found some patch object types in the process list, need to exclude catalogs
	while [ ${count} -le ${#catalogJobTypes} ]
		do
		BLCLICMD=(Utility convertModelType ${catalogJobTypes[${count}]})
		runBlcliCmd catalogJobTypeId
		BLCLICMD=(Job findAllHeadersByType ${catalogJobTypeId})
		runBlcliCmd
		BLCLICMD=(SJobHeader getDBKey)
		runBlcliCmd
		BLCLICMD=(Utility setTargetObject)
		runBlcliCmd
		BLCLICMD=(Utility listPrint)
		runBlcliCmd
		BLCLICMD=(Utility setTargetObject)
		runBlcliCmd jobKeys
		if [ "${catalogJobKeyList}x" = "x" ]
			then
			catalogJobKeyList=(${jobKeys})
		else
            catalogJobKeyList=(${jobKeys} ${catalogJobKeyList[@]})
		fi	
		local count=$((${count}+1))
	done
	
	print_debug3 "Found Catalog Job Ids: ${catalogJobKeyList[@]}"
	print_debug2 "Exiting function: ${0}..."
}

findAllCatalogObjects()
{
	print_debug2 "Entering function: ${0}..."

	local count=1
	while [ ${count} -le ${#catalogList[@]} ]
		do
		catalogTypeId="`echo ${catalogList[${count}]} | cut -f1 -d,`" && print_debug2 "catalogTypeId=${catalogTypeId}"
		catalogPath="`echo ${catalogList[${count}]} | cut -f2 -d,`" && print_debug2 "catalogPath=${catalogPath}"

		BLCLICMD=(PatchCatalog getCatalogIdByFullyQualifiedCatalogName "${catalogPath}" ${catalogTypeId})
		runBlcliCmd catalogId
		
		BLCLICMD=(DepotObject findAllHeadersByGroup ${catalogId})
		runBlcliCmd
		BLCLICMD=(Utility storeTargetObject objHeaders)
		runBlcliCmd
		BLCLICMD=(Utility listLength)
		runBlcliCmd listLength
		
		local count1=0
		while [ ${count1} -lt ${listLength} ]
			do
			BLCLICMD=(Utility setTargetObject objHeaders)
			runBlcliCmd
			BLCLICMD=(Utility listItemSelect ${count1})
			runBlcliCmd
			BLCLICMD=(Utility setTargetObject)
			runBlcliCmd
			BLCLICMD=(SDepotObjectHeader getDBKey)
			runBlcliCmd objKey
			BLCLICMD=(SDepotObjectHeader getName)
			runBlcliCmd objName
			BLCLICMD=(SDepotObjectHeader getObjectTypeId)
			runBlcliCmd objTypeId
			if [ "${scriptMode}" = "deleteCatalogObjects" ]
				then
				print_info "Deleting ${catalogPath}/${objName}..."
				if [ "${dryRun}" = "false" ]
					then
					BLCLICMD=(Delete deleteModelObjectAndDependentObjects ${objTypeId} ${objKey})
					runBlcliCmd
				else
					print_info "Dry Run Only, no change made..."
				fi
			elif [ "${scriptMode}" = "setCatalogObjectProperty" ]
				then
				setCatalogObjectProperty 
			elif [ "${scriptMode}" = "setPayloadLocation" ]
				then
				setPayloadLocation
			elif [ "${scriptMode}" = "setACLPolicy" ]
				then
				setACLPolicy
			elif [ "${scriptMode}" = "verifyObjects" ]
				then
				BLCLICMD=(DepotObject findByDBKey ${objKey})
				runBlcliCmd
				BLCLICMD=(DepotObject getLocation)
				runBlcliCmd objLocation
				# need to only check actual patch objects
				if [ -f "${objLocation}" ]
					then
					objExists="exists"
				else
					objExists="does not exist"
				fi
				# could add a rpm verify here
				print_info "${catalogPath}/${objName} ${objExists} at ${objLocation}"
			fi
			local count1=$((${count1}+1))
		done
		local count=$((${count}+1))
	done
}

findAllCatalogs()
{
	print_debug2 "Entering function: ${0}..."
	local count=1
	
	if [ "${catalogPath}x" != "x" ]
		then
		BLCLICMD=(Utility convertModelType ${catalogType})
		runBlcliCmd catalogTypeId
		catalogList=("${catalogTypeId},${catalogPath}")
	else
		for catalogJobKey in ${catalogJobKeyList[@]}
			do
			BLCLICMD=(Job jobKeyToJobId ${catalogJobKey})
			runBlcliCmd catalogJobId
			BLCLICMD=(PatchCatalog findCatalogByJobId ${catalogJobId})
			runBlcliCmd
			BLCLICMD=(Group getGroupId)
			runBlcliCmd groupId
			BLCLICMD=(Group getType)
			runBlcliCmd groupTypeId
			BLCLICMD=(Group getQualifiedGroupName ${groupTypeId} ${groupId})
			runBlcliCmd catalogPath
			if [ "${catalogList}x" = "x" ]
				then
				catalogList=("${groupTypeId},${catalogPath}")
			else
				catalogList=("${groupTypeId},${catalogPath}" "${catalogList[@]}")
			fi
		done
	fi
	
	print_debug3 "Found Catalogs: ${catalogList[@]}"
	
	print_debug2 "Exiting function: ${0}..."
}

setCatalogObjectProperty()
{
	# this requires a mapping file that can be parsed for each object
	BLCLICMD=(DepotObject findByDBKey ${objKey})
	runBlcliCmd
	BLCLICMD=(DepotObject getFullyResolvedValueAsString "${propName1}")
	runBlcliCmd propVal1
	
	print_error "Please update this function (setCatalogObjectProperty) with logic to read the property value from a source file"
	propVal2="`grep -w "${propVal1}" "${mapFile}" | cut -f2 -d,`"
	print_info "Setting ${propName2} to ${propVal2} on ${catalogPath}/${objName}..."
	
	if [ "${dryRun}" = "false" ]
		then
		BLCLICMD=(DepotObject ${objKey} "${propName2}" "${propValue2}")
		runBlcliCmd
	fi
}

setACLPolicy()
{
	print_debug2 "Entering function: ${0}..."
	BLCLICMD=(DepotObject findByDBKey ${objKey})
	runBlcliCmd
	BLCLICMD=(DepotObject getBlAcl)
	runBlcliCmd
	BLCLICMD=(Utility setTargetObject)
	runBlcliCmd
	BLCLICMD=(Utility storeTargetObject acl)
	runBlcliCmd
	BLCLICMD=(BlAcl aclToString NAMED_OBJECT=acl)
	runBlcliCmd aclList
	
	
	[ -f "${TMPDIR}/acl" ] && rm -f "${TMPDIR}/acl"
	while read line
		do
		echo "${line}" 
	done <<< ${aclList} | grep "Policy Name:" | cut -f2 -d: | sed "s/^ //g" >> "${TMPDIR}/acl"

	cat "${TMPDIR}/acl" | while read oldPolicyName
		do
		print_info "Removing ACLPolicy: ${oldPolicyName} from ${objName}..."
		if [ "${dryRun}" = "false" ]
			then
			BLCLICMD=(DepotObject removeAclPolicy ${objKey} "${oldPolicyName}")
			runBlcliCmd objKey
		else
			print_info "Dry Run Only, no change made..."
		fi
		
		print_info "Applying ACLPolicy: ${aclPolicy} to ${objName}..."
		if [ "${dryRun}" = "false" ]
			then
			BLCLICMD=(DepotObject applyAclPolicy ${objKey} "${aclPolicy}")
			runBlcliCmd
		else
			print_info "Dry Run Only, no change made..."
		fi
	done
	
	
	
	print_debug2 "Exiting function: ${0}..."
}

setCUJProperty()
{
	print_debug2 "Entering function: ${0}..."
	
	for catalogJobKey in ${catalogJobKeyList[@]}
		do
		BLCLICMD=(Job findByDBKey ${catalogJobKey})
		runBlcliCmd 
		BLCLICMD=(Job getName)
		runBlcliCmd jobName
		print_info "Setting ${propName1} to ${propVal1} on ${jobName}..."
		if [ "${dryRun}" = "false" ]
			then
			BLCLICMD=(Job setPropertyValue ${catalogJobKey} "${propName}" "${propVal}")
			runBlcliCmd
		else
			print_info "Dry Run Only, no change made..."
		fi
	done
	
	print_debug2 "Exiting function: ${0}..."
	
}

setPayloadLocation()
{
	print_debug2 "Enetering function: ${0}..."

	BLCLICMD=(DepotObject findByDBKey ${objKey})
	runBlcliCmd
	BLCLICMD=(DepotSoftware getLocation)
    runBlcliCmd oldLocation
    BLCLICMD=(DepotObject getName)
    runBlcliCmd objName
    # there's a defect in the 8.0/1/2 blcli command updateSourceLocation so we have to flip the value of the CopySourceToUndo
    # to have the new setting take effect
	BLCLICMD=(DepotSoftware getSkipCopySourceToUndo)
	runBlcliCmd copySource	
	[ ${copySource} = true ] && tmpSource=false
	[ ${copySource} = false ] && tmpSource=true	
	patchName="${oldLocation##*/}"
	newLocation="${newURL}/${objName}"
	
	print_info "Changing DepotObject Location from ${oldLocation} to ${newLocation} with URL Type ${newURLType}..."
	print_info "Please manually move ${oldLocation} to ${newLocation}..."
	if [ "${dryRun}" = "false" ]
		then
		BLCLICMD=(DepotSoftware updateSourceLocation "${objKey}" "${newLocation}" ${tmpSource} ${newURLType})
		runBlcliCmd newKey
		BLCLICMD=(DepotObject findByDBKey ${newKey})
		runBlcliCmd
		BLCLICMD=(Utility storeTargetObject depObj)
		runBlcliCmd
		BLCLICMD=(DepotSoftware setSkipCopySourceToUndo ${copySource})
		runBlcliCmd
		BLCLICMD=(DepotObject update NAMED_OBJECT=depObj)
		runBlcliCmd
	else
		print_info "Dry Run Only, no change made..."
	fi
	
	print_debug2 "Exiting function: ${0}..."
	
}

setFiles()
{
	print_debug2 "Entering function: ${0}..."

	BLCLIOUT="${TMPDIR}/out.blcli"
	BLCLIERR="${TMPDIR}/err.blcli"

	print_debug2 "Exiting function: ${0}..."
}

setObjTypes()
{
	print_debug2 "Entering function: ${0}..."
	catalogJobTypes=(OTHER_LINUX_PATCH_CATALOG_UPDATE_JOB REDHAT_PATCH_CATALOG_UPDATE_JOB SOLARIS_PATCH_CATALOG_UPDATE_JOB WINDOWS_PATCH_CATALOG_UPDATE_JOB)
	catalogGroupTypes=(OTHER_LINUX_CATALOG_GROUP RED_HAT_CATALOG_GROUP SOLARIS_CATALOG_GROUP WINDOWS_CATALOG_GROUP)
	patchObjTypes=(RPM_INSTALLABLE HOTFIX_WINDOWS_INSTALLABLE SOLARIS_PATCH_INSTALLABLE SOLARIS_PATCH_TCLUSTER_INSTALLABLE)
	
	if [ `echo ${bladeVersion} | grep -e "^8.1" -e "^8.2" | wc -l` -eq 1 ]
		then
		# new patch objects in 8.1
		patchObjTypes=(AIX_PACKAGE_INSTALLABLE AIX_FILESET_INSTALLABLE AIX_PATCH_INSTALLABLE ${patchObjTypes[@]})
		catalogJobTypes=(AIX_PATCH_CATALOG_UPDATE_JOB ${catalogJobTypes})
		catalogGroupTypes=(AIX_CATALOG_GROUP ${catalogGroupTypes[@]})
	fi	

	if [ "${catalogType}x" != "x" ]
		then
		catalogGroupTypes=(${catalogType})
		catalogJobTypes=(${catalogJobType})
	fi

	print_debug2 "Exiting function: ${0}..."
}

#############################
#
#####
# Temp Files
TMPDIR="/tmp/$$"
cleanupFiles=true
dryRun=true

SCRIPT_ARGS=$@          # In case we need it later (i.e. for parameters etc)
SCRIPT_NAME="${0}"
initScript "$@"


# setup the temp files
setFiles

# check the blade version
getBladeLogicVersion

# setup the object types to process
setObjTypes

if [ "${catalogPath}x" = "x" ]
	then
	# find all the catalogs jobs, need them to find the groups
	findAllCatalogJobs
fi


# check script mode
if [ "${scriptMode}" = "setCUJProperty" ]
	then
	updateCUJProperty
else
	findAllCatalogs
	if [ "${scriptMode}" = "listAllCatalogPaths" ]
		then
		count=1
		print_info "Listing Patch Catalog Paths..."
		while [ ${count} -le ${#catalogList[@]} ]
		do
			print_info "`echo ${catalogList[${count}]} | cut -f2 -d,`"
			count=$((${count}+1))
		done
	else
		findAllCatalogObjects
	fi
fi



#####
# End of custom code
#####
 
cleanupEnv
print_info "Exiting script..."
exit 0

#####################################################################
# END
#####################################################################


