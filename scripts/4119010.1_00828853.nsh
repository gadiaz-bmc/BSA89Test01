#!/bin/nsh
blcli_connect

jobGroup="/Navisite/NON-SIAS/Windows/Reporting/Windows_SW_Inventory_Report"
jobName="Windows_SW_Inventory_Report"
date=`date +'%Y%m%d-%H%M%S'`

blcli_execute Util getSystemProperty DatabaseVersion true
blcli_storeenv bladeVersion

blcli_execute SnapshotJob getDBKeyByGroupAndName "${jobGroup}" "${jobName}"
blcli_storeenv jobKey
blcli_execute JobRun findLastRunKeyByJobKey ${jobKey}
blcli_storeenv jobRunKey
blcli_execute JobRun jobRunKeyToJobRunId ${jobRunKey}
blcli_storeenv jobRunId
echo "Server,Name,Description,Version,Vendor,Category,Install Date,Size," >> /tmp/Consolidated-${jobName}-Report-${date}.csv

if [ "${bladeVersion}" = "7.6.0" ]
	then
	blcli_execute LogItem getLogItemsByJobRun ${jobKey} ${jobRunId}
	blcli_execute Utility setTargetObject
	blcli_execute JobLogItem getDeviceId
	blcli_execute Utility setTargetObject
	blcli_execute Utility listPrint
	blcli_storeenv deviceIds
	for deviceId in ${deviceIds}
		do
		if [ ${deviceId} != 0 ]
			then
			blcli_execute Server findById ${deviceId}
			blcli_execute Server getName
			blcli_storeenv serverName
			srvServers="${serverName} ${srvServers}"
		fi
	done
	serverList="$(for server in ${srvServers}; do echo ${server}; done | sort -u)"
else
	blcli_execute JobRun getTargetsForJobRunId ${jobRunId}
	blcli_execute Utility mapPrint
	blcli_storeenv targetMap
	echo "${targetMap}" > $$.out

	componentKeys=`grep "^COMPONENT" $$.out | cut -f2 -d= | sed "s/\[//g;s/\]//g" | sed "s/,//g"`
	for componentKey in ${componentKeys}
        	do
	        componentKey=`echo ${componentKey} | sed "s/\(.*\):.*/\1/g"`
	        blcli_execute Component findByDBKey ${componentKey}
        	blcli_execute Component getDeviceId
	        blcli_storeenv serverId
        	blcli_execute Server findById ${serverId}
	        blcli_execute Server getName
        	blcli_storeenv serverName
	        cmpServers=(${serverName} ${cmpServers[@]})
	done

	serverKeys=`grep "^SERVER" $$.out | cut -f2 -d= | sed "s/\[//g;s/\]//g" | sed "s/,//g"`
	for serverKey in ${serverKeys}
        	do
	        serverKey=`echo ${serverKey} | sed "s/\(.*\):.*/\1/g"`
        	blcli_execute Server findById ${serverKey}
	        blcli_execute Server getName
        	blcli_storeenv serverName
	        srvServers=(${serverName} ${srvServers[@]})
	done
	serverList=(${cmpServers[@]} ${srvServers[@]})
fi

for server in ${serverList}
do
blcli_execute Utility exportSnapshotRun "${jobGroup}" "${jobName}" ${jobRunId} "" "" ${server} "/tmp/${server}-${jobName}-${date}.csv" CSV
sed -n '11,$p' < /tmp/${server}-${jobName}-${date}.csv > /tmp/${server}-${jobName}-${date}_1.csv
awk -v dt="${server}" 'BEGIN{FS=OFS=","}{$1=dt}1' /tmp/${server}-${jobName}-${date}_1.csv >> /tmp/Consolidated-${jobName}-Report-${date}.csv
rm -rf /tmp/${server}-${jobName}-${date}.csv /tmp/${server}-${jobName}-${date}_1.csv
done
cp /tmp/Consolidated-${jobName}-Report-${date}.csv //165.113.13.172/e/TSSA_Reports
cp /tmp/Consolidated-${jobName}-Report-${date}.csv //165.113.13.173/e/TSSA_Reports
rm -f $$.out /tmp/Consolidated-${jobName}-Report-${date}.csv


blcli_disconnect