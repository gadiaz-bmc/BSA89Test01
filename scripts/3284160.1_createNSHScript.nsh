tmpDir="/C"
script="serverName2.ps1"
#sample script contents
echo '$comp="."' > "//${targetserver}${tmpDir}/${script}"
echo '$Servidor = Write-output $Env:ComputerName' >> "//${targetserver}${tmpDir}/${script}"

nexec -D //${targetserver}${tmpDIr} -i -l ${targetserver} cmd.exe /c "powershell -inputformat none ${script}" 
[[ -f "//${targetserver}${tmpDir}/${script}" ]] && rm -f "//${targetserver}${tmpDir}/${script}"