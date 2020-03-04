#blcli_execute Server printPropertyByName "clm-aus-017854.bmc.com" OS
blcli_setjvmoption -Dcom.bladelogic.cli.execute.quietmode.enabled=false
blcli_execute Server printPropertyValue "clm-aus-017854.bmc.com" OS
#blcli_storeenv Value
#echo $Value