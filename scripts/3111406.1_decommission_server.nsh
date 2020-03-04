serverlist=$*
code=0
for servername in $serverlist
do
	echo "decommissioning $servername..."
#	if [ $servername = "enter" ]; then
#		code=1
#		echo "ERROR: did not set the serverlist parameter correctly, job exiting!"
#		break
#	fi
	blcli_execute Server decommissionServer $servername
	if test $? -ne 0
	then
		echo "Failed to decommission $servername, setting job exit code to 1" 
		code=1
	fi
	echo ""
done
#echo "clearing param list for next run..."
#blcli_execute NSHScriptJob clearNSHScriptParameterValuesByGroupAndName "/System Maintenance" "(Ex Ov) Decommission Servers"
exit $code
