blcred cred -acquire -profile BLAdmin -username BLAdmin -password bmcAdm1n
blcli_setoption serviceProfileName BLAdmin
blclI_setoption roleName BLAdmins
blcli_setoption ssoCredCacheOpt /C/Users/Administrator/AppData/Roaming/BladeLogic/bl_sesscc
blcli_connect
blcli_execute Server listAllServers
blcli_storeenv SERVERS
for  SERVER in ${SERVERS}
do
blcli_execute Server setPropertyValueByName ${SERVER} "DESCRIPTION" "maheshbabu"
done 
