date /t
time /t
 
wsl -d Ubuntu-22.04 -u root ip addr del $(ip addr show eth0 ^| grep 'inet\b' ^| awk '{print $2}' ^| head -n 1) dev eth0
wsl -d Ubuntu-22.04 -u root ip addr add 192.168.80.2/24 broadcast 192.168.80.255 dev eth0
wsl -d Ubuntu-22.04 -u root ip route add 0.0.0.0/0 via 192.168.80.1 dev eth0
wsl -d Ubuntu-22.04 -u root echo nameserver 8.8.8.8 ^> /etc/resolv.conf
wsl -d Ubuntu-22.04 -u root chattr +i /etc/resolv.conf
 
powershell -c "Get-NetAdapter 'vEthernet (WSL)' | Get-NetIPAddress | Remove-NetIPAddress -Confirm:$False; New-NetIPAddress -IPAddress 192.168.80.1 -PrefixLength 24 -InterfaceAlias 'vEthernet (WSL)'; Get-NetNat | ? Name -Eq WSLNat | Remove-NetNat -Confirm:$False; New-NetNat -Name WSLNat -InternalIPInterfaceAddressPrefix 192.168.88.0/24;"
 
date /t
time /t

pause
