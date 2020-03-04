#!/bin/nsh
#
# For debug uncomment this line:
# set -x
#
# vim:syntax=sh
#******************************************************************************
# File Name:  cleanup_Agent.nsh
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
#  This script will delete files in Transactions, stage, and rscd_tmp directories based on the retention 
#  time.  If directories are empty, it deletes them with an exception to:
#          -  Transactions/mnt
#          -  Transactions/locks
#          -  Transactions/Database
#          -  Transactions/events
#          -  Transactions/logs

#  If does not clean:
#      (File) doNOTdeleteSupportFilesUsed.txt -- If enviroment was upgrade from 7.5 at some point...
#      (Dir) lost+found                       -- If agent is a repeater
#  
#
#
# Revision History:
# ================
# Version  Date               Description
# -------+------------+------------------+-------------------------------------
#  v1.0    14-Dec-2016       Initial Creation
#  v1.1	   19-Dec-2016       Collapse clean functions, more error checking
#
#***
#
##############################################################################
#      CLENAUP_AGENT SCRIPT
#####
# Temp Files
#TMPDIR="/tmp/tmp_$$"
###################
# PRINT FUNCTIONS
###################
 
# Note:  
 
print_info()
{
	print "[INFO] ${@}"
	return 0
}
 
print_error()
{
	print -u2 "[ERROR] ${@}"
	return 0
}
 
print_exit()
{
	print -u2 "[ERROR] ${@}"
	exit 1
}

print_warn()
{
	print "[WARN] ${@}"
	return 0
}
 
print_debug()
{
	[[ "${DEBUGLEVEL}" -ge "0" ]] && print "[DEBUG] ${@}"
	return 0
}
 
print_debug1()
{
	[[ "${DEBUGLEVEL}" -ge "1" ]] && print "[DEBUG1] ${@}"
	return 0
}
 
print_debug2()
{
	[[ "${DEBUGLEVEL}" -ge "2" ]] && print "[DEBUG2] ${@}"
	return 0
}

print_debug3()
{
	[[ "${DEBUGLEVEL}" -ge "3" ]] && print "[DEBUG3] ${@}"
	return 0
}

print_result()
{
	print "  RESULT: ${@}"
	return 0
}

print_variable()
{
	[[ "${DEBUGLEVEL}" -ge "2" ]] && print "[$(date)] [VARIABLE] ${1}: $(printf '%q' ${(P)${1}//[[:cntrl:]]/ })"
	return 0
}
####################
# UTILITY FUNCTIONS
####################
 
#####
# Usage command
#
# Arguments:
#   $1   Required exit code - defaults to 1.
#
usage()
{
	print_debug1 "Entering function: ${0}..."
	if [[ "$#" -eq "10" ]]
		then
		processParameters "$@"
		USAGE_CODE=0
	else
		USAGE_CODE=1
		echo "Usage: cleanupAgent.nsh -d '<debug_level>'  -h '<Host>' -r '<retention>' -s '<staging_dir>' -t '<transactions_dir' -a '<rscd dir>' -v '<rscd_tmp>' -m '<date type>'"
		echo "-d	<debug_level>			- logging levels from 0 to 3"
		echo "-r	<retention>				- Retention in days"
		echo "-s	<staging_dir>			- Stage directory"
		echo "-t	<transactions_dir>		- transactions directory"
		echo "-a	<rscd dir>				- rscd directory"
														 
		echo "-h	<target>				- target server, not needed if run via runscript"
		echo "-v	<rscd_tmp>				- rscd tmp directory"
		echo "-m	<date type>				- one of mtime, atime or ctime"
		echo ""
		echo ""
		exit ${USAGE_CODE}
	fi
	print_debug1 "Exiting function: ${0}..."
}

#####
# All parameters should be handled in this function.
#
processParameters()
{
	print_debug1 "Entering function: ${0}..."

	while getopts d:r:s:t:a:m:h:v: Option
	do
		case $Option in
			d) DEBUGLEVEL=${OPTARG}
			print_variable "DEBUGLEVEL"
			;;	
			r) RETENTION="${OPTARG}"
			print_variable "RETENTION"
			;;
			s) STAGING_DIR="${OPTARG}"
			print_variable "STAGING_DIR"
			;;
			t) TRANSACTIONS_DIR="${OPTARG}"
			print_variable "TRANSACTIONS_DIR"
			;;
			a) RSCD_DIR="${OPTARG}"
			print_variable "RSCD_DIR"
			;;
			m) DATE_TYPE="${OPTARG}"
			print_variable "DATE_TYPE"
			;;
			h) TARGET="${OPTARG}"
			print_variable "TARGET"
			;;
			v) RSCD_TMP="${OPTARG}"
			print_variable "RSCD_TMP"
			;;
			*) 
			;;
		esac
	done

	[[ "${DEBUGLEVEL}" -le "0" ]] && DEBUGLEVEL=0
	[[ "${DEBUGLEVEL}" -gt "0" ]] && print_info "Running at Debug level ${DEBUGLEVEL}"
	[[ "${DEBUGLEVEL}" -ge "3" ]] && set -x

	print_debug1 "Exiting function: ${0}..."
}

#####
# Temp File functions
initTmpFile()
{
	print_debug1 "Entering function: ${0}..."
	local deletedFiles="//${NSH_RUNCMD_HOST}${RSCD_DIR}/tmp/deletedFiles.txt"

	# Remove so new list can be generated...
	[[ -s ${deletedFiles} ]] && rm -rf "${deletedFiles}"
	print_debug1 "Exiting function: ${0}..."
}

#####
# In various situations we need to pipe the output of certain commands to
# NULL.  Since this differs depending on the system on which the script is
# being run, we set it dynamically here.
setNull()
{
	print_debug1 "Entering function: ${0}..."

	if ( grep -q "^Windows" <<< $(uname -s) )
	then
		print_debug3 "Setting NULL for a Windows platform"
		NULL="ERR_NUL"
	else
		print_debug3 "Setting NULL for a UNIX platform"
		NULL="/dev/null"
	fi
	print_debug1 "Exiting function: ${0}..."
}

#####
# CheckInput
#
checkInput()
{
	print_debug1 "Entering function: ${0}..."

	if [[ ! -z ${NSH_RUNCMD_HOST} ]]
	then
		TARGET=${NSH_RUNCMD_HOST}
		print_debug1 "Running via runscript, using ${NSH_RUNCMD_HOST} as TARGET..."
	fi

    # TARGET
	if [[ -z ${TARGET} ]]
	then
		print_exit "TARGET (-h) not set..."
	else
		print_debug1 "Running without runscript, using ${TARGET} as TARGET..."
	fi

	# DATE_TYPE
	[[ "${DATE_TYPE/(mtime|atime|ctime)}" = "${DATE_TYPE}" ]] && print_exit "DATE_TYPE (-d) must be one of: mtime, ctime, atime, not ${DATE_TYPE}..."

	if [[ ! ${RETENTION} = <-> ]]
	then
		print_exit "RETENTION (-r) must be a number..."
		if [[ ! ${RETENTION} -gt 0 ]]
		then
			print_exit "RETENTION (-r) must be greater than 0..."
		fi
	fi

	# TRANSACTIONS_DIR
	if [[ -z ${RSCD_DIR} ]] && [[ -z ${TRANSACTIONS_DIR} ]]
	then
		print_exit "RSCD_DIR or TRANSACTIONS_DIR must be set..."
	elif [[ -n ${RSCD_DIR} ]] && [[ -z ${TRANSACTIONS_DIR} ]]
	then
		if [[ -d "//${TARGET}${RSCD_DIR}/Transactions" ]]
	    then
			TRANSACTIONS_DIR="${RSCD_DIR}/Transactions"
		else
			print_exit "${RSCD_DIR}/Transactions does not exist..."
		fi
	elif ([[ -z ${RSCD_DIR} ]] || [[ -n ${RSCD_DIR} ]]) && [[ -n ${TRANSACTIONS_DIR} ]]
		then
		[[ ! -d "//${TARGET}${TRANSACTION_DIR}" ]] && print_exit "TRANSACTIONS_DIR: ${TRANSACTIONS_DIR} does not exist on ${TARGET}..."
	else
		print_exit "Cannot find TRANSACTIONS_DIR..."
	fi

	# RSCD_TMP
	if [[ -z ${RSCD_DIR} ]] && [[ -z ${RSCD_TMP} ]]
	then
		print_exit "RSCD_DIR or RSCD_TMP must be set..."
	elif [[ -n ${RSCD_DIR} ]] && [[ -z ${RSCD_TMP} ]]
	then
		if [[ -d "//${TARGET}${RSCD_DIR}/tmp" ]]
	    then
			RSCD_TMP="${RSCD_DIR}/tmp"
		else
			print_exit "${RSCD_DIR}/tmp does not exist..."
		fi
	elif ([[ -z ${RSCD_DIR} ]] || [[ -n ${RSCD_DIR} ]]) && [[ -n ${RSCD_TMP} ]]
		then
		[[ ! -d "//${TARGET}${RSCD_TMP}" ]] && print_exit "RSCD_TMP: ${RSCD_TMP} does not exist on ${TARGET}..."
	else
		print_exit "Cannot find RSCD_TMP..."
	fi
	
	# Loop: RSCD_DIR TRANSACTIONS_DIR STAGING_DIR TARGET RETENTION DATE_TYPE RSCD_TMP
	for i in RSCD_DIR TRANSACTIONS_DIR STAGING_DIR TARGET RETENTION DATE_TYPE RSCD_TMP
	do
		print_variable "${i}"
	done

	print_debug1 "Exiting function: ${0}..."
}

#####
# cleanDir
#

cleanDir()
{
	print_debug1 "Entering function: ${0}..."

	local target="${1}" && print_variable "target"
	local targetDir="${2}" && print_variable "targetDir"
	local retention="${3}" && print_variable "retention"
	local dateType="${4}" && print_variable "dateType"
	local retVal
	local fcount=0
	local retCode0=0
	local retCode1=0
 
	if [[ -d "//${target}${targetDir}" ]]
	then
		print_info "Processing //${target}${targetDir} for ${dateType} of ${retention}..."
		items="$(find "//${target}${targetDir}" -maxdepth 2 -${dateType} +${retention})"
		if [[ -n "${items}" ]]
		then
			while read i
			do
				if [[ "${i/Transactions\/(mnt|locks|Database|events|log|lost+found)}" = "${i}" ]] && [[ "${i}" != "//${target}${targetDir}" ]]
				then
					print_info "Removing ${i}..."
					rm -rf "${i}"
					if [[ $? -eq 0 ]]
					then
						let fcount+=1
					else
						print_error "Cannot delete ${i}..."
						let retCode0+=1
					fi
				fi
				# make sure log directory is cleaned....
				if if [[ "${i/Transactions\/(mnt|locks|Database|events|lost+found)}" = "${i}" ]] && [[ "${i/Transactions\/log\/(tmp)}" = "${i}" ]] && [[ "${i}" != "//${target}${targetDir}/log" ]]
				then
					print_info "Removing ${i}..."
					rm -rf "${i}"
					if [[ $? -eq 0 ]]
					then
						let fcount+=1
					else
						print_error "Cannot delete ${i}..."
						let retCode0+=1
					fi
				fi
			done <<< "${items}"
		fi
		print_info "Total \"${targetDir}\" Files deleted: ${fcount}"
		# remove empty directories
		fcount=0
		print_info "Processing //${target}${targetDir} for empty directories..."
		while read i
		do
			if [[ "${i}" != "/" ]] && [[ "${i/Transactions\/(mnt|locks|Database|events|log|lost+found)}" = "${i}" ]] && [[ "${i}" != "//${target}${targetDir}" ]]
				then
				print_info "Removing empty directory ${i}..."
				rm -rf "${i}"
				if [[ $? -eq 0 ]]
				then
					let fcount+=1
				else
					print_error "Cannot delete ${i}..."
					let retCode1+=1
				fi
			fi
		done <<< "$(find "//${target}${targetDir}" -empty)"
		print_info "Total \"${targetDir}\" Empty Directories deleted: ${fcount}"
	else
		print_warn "Target Directory: ${targetDir} directory does not exist on ${target}..."
	fi

	print_debug1 "Exiting function: ${0}..."
	return $((${retCode0}+${retCode1}))
}

#####
# This function initialises the environment and MUST be called at the start
# of the main code!
initScript()
{
	print_debug1 "Entering function: ${0}..."
	[[ ${#@} -eq 0 ]] && usage
	processParameters "${@}"
	checkInput
	setNull 
	initTmpFile
	print_debug1 "Exiting function: ${0}..."
}

handleExitCode()
{
	print_debug1 "Entering function: ${0}..."
	local RT_CC=0
	cleanDir "${TARGET}" "${STAGING_DIR}" ${RETENTION} "${DATE_TYPE}"
	if [[ $? -ne 0 ]]
	then
		print_error "Errors during Staging directory cleanup..."
		let RT_CC+=1
	fi

	cleanDir "${TARGET}" "${TRANSACTIONS_DIR}" ${RETENTION} "${DATE_TYPE}"
	if [[ $? -ne 0 ]]
	then
		print_error "Errors during Transaction directory cleanup..."
		let RT_CC+=1
	fi

	
	cleanDir "${TARGET}" "${RSCD_TMP}" ${RETENTION} "${DATE_TYPE}"
	if [[ $? -ne 0 ]]
	then
		print_error "Errors during tmp directory cleanup..."
		let RT_CC+=1
	fi
	
	print_debug1 "Exiting function: ${0}..."
	return ${RT_CC}
}

#####################################################################
# MAIN CODE
#####################################################################
#
# Require parameters: STAGING_DIR and RSCD_DIR. 
# TRANSACTIONS_DIR:   Dir should be provided if it was changed to a 
#                     location other than the default ??TARGET.RSCD??/Transactions.
# RSCD_TMP: 		  default location not required 
# RETENTION:          default to 14 days.
# DATE_TYPE:          default to mtime but customer can use atime or ctime by 
#                     by providing the value to the parameters in the 
#                     nsh-script job.
#		

DEBUGLEVEL=0
RETENTION=14
STAGING_DIR=
TRANSACTIONS_DIR=
RSCD_DIR=
DATE_TYPE="mtime"
TARGET=
RSCD_TMP=
initScript "$@"
handleExitCode 
if [[ $? -ne 0 ]]
then
	exit 1
fi

##############################################################################
# End of cleanup_Agent.nsh
##############################################################################