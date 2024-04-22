If ("myNAT" -in (Get-VMSwitch | Select-Object -ExpandProperty Name) -eq $FALSE) {
    'Creating Internal-only switch "myNAT" on Windows Hyper-V host...'

    New-VMSwitch -SwitchName "myNAT" -SwitchType Internal

    New-NetIPAddress -IPAddress 192.168.120.1 -PrefixLength 24 -InterfaceAlias "vEthernet (myNAT)"

    New-NetNAT -Name "myNAT" -InternalIPInterfaceAddressPrefix 192.168.120.0/24
}
else {
    'Internal-only switch "myNAT" for static IP configuration already exists; skipping'
}

If ("192.168.120.1" -in (Get-NetIPAddress | Select-Object -ExpandProperty IPAddress) -eq $FALSE) {
    'Registering new IP address 192.168.120.1 on Windows Hyper-V host...'

    New-NetIPAddress -IPAddress 192.168.120.1 -PrefixLength 24 -InterfaceAlias "vEthernet (myNAT)"
}
else {
    'IP address "192.168.120.1" for static IP configuration already registered; skipping'
}

If ("192.168.120.0/24" -in (Get-NetNAT | Select-Object -ExpandProperty InternalIPInterfaceAddressPrefix) -eq $FALSE) {
    'Registering new NAT adapter for 192.168.120.0/24 on Windows Hyper-V host...'

    New-NetNAT -Name "myNAT" -InternalIPInterfaceAddressPrefix 192.168.120.0/24
}
else {
    '"192.168.120.0/24" for static IP configuration already registered; skipping'
}
