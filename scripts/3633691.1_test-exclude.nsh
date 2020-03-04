
blcli_execute Server listAllServerIds
blcli_storelocal SERVER_LIST
for serverId in $SERVER_LIST
do
  blcli_execute ExcludePatchDevice resetExcludePatchListForDevice $serverId
done
