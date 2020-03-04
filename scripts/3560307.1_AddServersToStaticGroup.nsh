#!/bin/sh
#
# Use this script to add a lot of servers to a static server group
# Script will read a text file containing the list of servers and loop through it adding each one to the static server group
# 

## Workaround for broken blcli_connect
## disabled Nov 15 2010 per Steve Pitcher
##############
# if test -z "$BLCLI_FIRST_TIME"
# then
	# LD_LIBRARY_PATH=/usr/bl/appserv/lib
	# export LD_LIBRARY_PATH
	# BLCLI_FIRST_TIME=false
	# export BLCLI_FIRST_TIME
	# unset CLI_SRP_CREDS
	# unset CLI_SSO_CREDS
	# exec nsh $0 "$@"
# fi
##############
# blcli_setoption authType BLSSO
# blcli_setoption serviceProfileName BNYMellon
# blcli_setoption roleName SSM_WindowsAdmins

# blcred cred -acquire -profile BNYMellon -username "?????????" -password "?????????"
##############


# Error codes
ERR_SANITY=1
ERR_CONNECT=2
ERR_GROUP=3
ERR_SERVER=4
ERR_ARGS=5

# Check arguments and exit if any are missing
if [ $# -lt 3 ]; then
	echo 1>&2 Usage: $0 folder filename group_parent \[group_name\]
	echo 1>&2
	echo 1>&2      folder - Network folder where input file is saved
	echo 1>&2      filename - Input filename
	echo 1>&2      group_parent - BladeLogic static group where group to be populated exists
	echo 1>&2      group_name - (Optional) Name of import group (if blank, a name will be automatically generated)
	echo 1>&2
	exit $ERR_ARGS
fi

# Server list must be in text format, one server per line (no header)
FILE_PREFIX=$1
SERVER_FILE=$2
GROUP_PREFIX=$3
GROUP_NAME=$4

DATE_SUFFIX=`date +%Y-%m-%d_%H%M%S`
ERROR_FILE=$FILE_PREFIX/import_errors_$DATE_SUFFIX.txt
RETURN_CODE=0

# Sanity check
if [ -z $FILE_PREFIX ] || [ -z $GROUP_PREFIX ]; then
	echo "($ERR_SANITY) ERROR: Must specify an import file folder and a parent group."
	exit $ERR_SANITY
fi

# Provide default values if file empty
if [ -z $SERVER_FILE ]; then
	SERVER_FILE=import.txt
fi
SERVER_FILE=$FILE_PREFIX/$SERVER_FILE

if [ -z $GROUP_NAME ]; then
	GROUP_NAME=auto_import_$DATE_SUFFIX
fi
echo "Sanity check complete."

# Initiate BL connection
blcli_connect
if [ $? -ne 0 ]; then
	echo "($ERR_CONNECT) ERROR: blcli_connect returned code $?"
	exit $ERR_CONNECT
fi

# If group does not exist, create it
blcli_execute StaticServerGroup groupExists "$GROUP_PREFIX/$GROUP_NAME"
blcli_storeenv GROUP_EXISTS
if [ $GROUP_EXISTS = "false" ]; then 
	blcli_execute StaticServerGroup createGroupWithParentName "$GROUP_NAME" "$GROUP_PREFIX"
	if [ $? -eq 0 ]; then
		echo "Group created: $GROUP_PREFIX/$GROUP_NAME"
	else
		echo "($ERR_GROUP) ERROR: Could not create group $GROUP_PREFIX/$GROUP_NAME"
		blcli_disconnect
		exit $ERR_GROUP
	fi
fi

GROUP=$GROUP_PREFIX/$GROUP_NAME
blcli_execute ServerGroup groupNameToId "$GROUP"
blcli_storeenv SERVER_GROUP_ID
blcli_execute ServerGroup addPermission "$GROUP" BLAdmins ServerGroup.\*
blcli_execute ServerGroup addPermission "$GROUP" BLAdmins ServerGroup.\*
blcli_execute ServerGroup addPermission "$GROUP" BLAdmins ServerGroup.\*
# sleep 10
# echo "======================================================================"
# blcli_execute ServerGroup showPermissions "$GROUP"
# end

# Iterate through list and add
cat $SERVER_FILE | while read SERVER
do
	blcli_execute StaticServerGroup addServerToServerGroupByName $SERVER_GROUP_ID $SERVER
	# Log errors
	if [ $? -ne 0 ]; then
		echo "$SERVER" >> $ERROR_FILE
		RETURN_CODE=$ERR_SERVER
	else
		echo "$SERVER added to group" 
	fi
done

blcli_disconnect
exit $RETURN_CODE