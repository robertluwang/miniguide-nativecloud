date /t
time /t

powershell -c "Get-NetAdapter 'vEthernet (myNAT)' | Get-NetIPAddress | Remove-NetIPAddress -Confirm:$False; New-NetIPAddress -IPAddress 192.168.120.1 -PrefixLength 24 -InterfaceAlias 'vEthernet (myNAT)'; Get-NetNat | ? Name -Eq myNAT | Remove-NetNat -Confirm:$False; New-NetNat -Name myNAT -InternalIPInterfaceAddressPrefix 192.168.120.0/24;"

date /t
time /t

pasue
