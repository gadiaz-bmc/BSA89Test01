#!/bin/nsh
Set -x
 

# Link documentação BMC - BLCLI Commands:

# https://docs.bmc.com/docs/display/public/bsacli88/Home

 

 

blcli_setoption serviceProfileName defaultProfile

blcli_setoption roleName BLAdmins

#blcli_setoption outputRedirectingDisable false

blcli_connect

 

# VARIÁVEIS MAPEADAS:

DOMINIO=$1

 

# LISTAR TODAS AS ROLES:

#ROLES=`blcli RBACRole listAllRoleNames`

blcli_execute RBACRole listAllRoleNames 

blcli_storeenv ROLES

 

for roleName in $ROLES;

do

      echo "ROLE: $roleName"

      # SINCRONIZAR ROLE COM O GRUPO DO AD:

      blcli_execute RBACRole syncUsersWithNameSuffix $roleName $DOMINIO
	  
	  if test $? -ne 0
	  then
	  echo "Failed to execute blcli_execute RBACRole syncUsersWithNameSuffix $roleName $DOMINIO" 
	  exit 1
	  fi
     

      #LISTAR TODOS OS USUÁRIOS DE CADA ROLE:

      #USERSROLE=`blcli RBACUser getAllUserNamesByRole $roleName`     

      blcli_execute RBACUser getAllUserNamesByRole $roleName

      blcli_storeenv USERSROLE

     

done
