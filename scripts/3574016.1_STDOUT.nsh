####################
# HERE IS EXAMPLE CODE:
####################

#!/usr/bin/nsh

echo 'Testing -- blcli_execute stdout:'
BLCLI_EXECUTE_VAR=`blcli_execute "NSHScriptJob" getDBKeyByGroupAndName "/User_Space/edgonzal" "NSH_STDOUT_Smita_Case"`
echo "BLCLI_EXECUTE_VAR = $BLCLI_EXECUTE_VAR"

echo 'Testing -- blcli_execute + blcli_storeenv stdout:'
blcli_execute "NSHScriptJob" getDBKeyByGroupAndName "/User_Space/edgonzal" "NSH_STDOUT_Smita_Case"
blcli_storeenv BLCLI_EXECUTE_w_STORED_VAR
echo "BLCLI_EXECUTE_w_STORED_VAR = $BLCLI_EXECUTE_w_STORED_VAR"

echo 'Testing -- blcli stdout:'
BLCLI_VAR=`blcli "NSHScriptJob" getDBKeyByGroupAndName "/User_Space/edgonzal" "NSH_STDOUT_Smita_Case"`
echo "BLCLI_VAR = $BLCLI_VAR"

exit
