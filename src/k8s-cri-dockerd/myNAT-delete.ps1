If (Get-VMSwitch | ? Name -Eq myNAT) {
    'Deleting Internal-only switch named myNAT on Windows Hyper-V host...'
    Remove-VMSwitch -Name myNAT
}
else {
    'VMSwitch "myNAT" not exists; skipping'
}

If (Get-NetIPAddress | ? IPAddress -Eq "192.168.120.1") {
    'Deleting IP address 192.168.120.1 on Windows Hyper-V host...'
    Remove-NetIPAddress -IPAddress "192.168.120.1"
}
else {
    'IP address "192.168.120.1" not existing; skipping'
}

If (Get-NetNAT | ? Name -Eq myNAT) {
    'Deleting NAT adapter myNAT on Windows Hyper-V host...'
    Remove-NetNAT -Name myNAT
}
else {
    'NAT adapter myNAT not existing; skipping'
}
