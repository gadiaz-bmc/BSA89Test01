RETENTION=5

currhost=$(hostname)

SERVER=target.domain
SERVER="$(cut -d'.' -f1 <<<$SERVER)"
echo $SERVER
echo $currhost $RETENTION

blcli Delete cleanupAgent $currhost $RETENTION     #>>$LOG_FILE