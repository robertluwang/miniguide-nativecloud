# Build k8s Cluster on Hyper-V
## Intro 
I used Virtualbox to launch Linux vm using Vagrant for many years, have to switch to Hyper-V due to it by default enabled in win10 host.

The outstanding point comparing to Virtualbox is that it supports nested virtualization, means you can use kvm hypervisor on top of Hyper-V Linux VM, to launch nested vm easily.

The drawback or learning curve with Hyper-V is that network model is different than Virtualbox. 

I will address few pain points and go through completely k8s lab deployment on top of Hyper-V on win10 host in this post.

- static ip for Hyper-V vm and permanent ip for k8s API server
- experiment k8s setup automation with Vagrant  

## Lab env
- Win10 32GB RAM
- Hyper-V 
- vagrant 2.4.1 windows
- WSL2 optional as terminal 

## k8s hyperv tool set 

We heavy use [handy scripts](https://github.com/robertluwang/hands-on-nativecloud/tree/main/src/k8s-cri-dockerd) to make k8s cluster on Hyper-V automatically, you can clone to local or download them manually, 

```
git clone git@github.com:robertluwang/hands-on-nativecloud.git
cd ./hands-on-nativecloud/src/k8s-cri-dockerd
```

## Hyper-V network

`3 types`:

- private - vm<->vm only
- internal - vm<->vm, vm<->host, vm->Internet if NAT enabled
- external - kind of bridge, vm<->host, vm->Internet

`private network`
It is isolated network, vm can access each other only.

`internal network`
It is private network plus host communication due to virtual NIC on host.

It is similar with Host-only in Virtualbox.

It could be further as NAT to allow vm to access Internet by adding internal network in NetNat, which enabling the routing traffic to outside.

The "Default Switch" is default NAT switch, the only issue is switch ip always changed after reboot; also DNS not working well. As remedy you can manually change vm ip and DNS inside vm, to match new change on Default Switch.

The good news is that it is possible to setup own static NAT network, to have stable test lab env, which is host-only + NAT if comparing with Virtualbox.

`external switch`
External switch will bind with physical NIC on host, sharing same network with host to access outside, ip assigned from DHCP.

In my pc there is only Wi-Fi adaptor, so external switch will bind to Wi-Fi adaptor, it always crashes and lost all Wi-Fi Internet access during creating, have to recover by Network Reset.

Let's forget about external switch for wi-fi at all, since it will directly impact host network access.

So Internal network + NAT is best and stable option for static IP, it allow host and vm talk each other and also access to Internet.

## Create own NAT switch 
We need to create new Hyper-V switch for example myNAT as type of Internal either from Hyper-V Manager GUI or Powershell as admin role, then create vNIC network like 192.168.120.0/24, and enable as NAT.

You can run PowerShell term as admin on win10 host, then run below [script](https://github.com/robertluwang/hands-on-nativecloud/blob/main/src/k8s-cri-dockerd/myNAT.ps1) to complete vm switch, vNIC and NAT setup.

Please change your prefer values in script:

- hyperv switch name: myNAT
- vEthernet ip: 192.168.120.1  it is gateway on win host 
- NetNAT name: myNAT
- NetNAT network: 192.168.120./24

`myNAT.ps1`
```
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
```
Here is sample of running result, 
```
.\myNAT.ps1
Creating Internal-only switch named "myNAT" on Windows Hyper-V host...

Name   SwitchType NetAdapterInterfaceDescription
----   ---------- ------------------------------
myNAT Internal                                 

IPv4Address              : 192.168.120.1
IPv6Address              : 
IPVersionSupport         : 
PrefixLength             : 24
SubnetMask               : 
AddressFamily            : IPv4
AddressState             : Tentative
InterfaceAlias           : vEthernet (myNAT)
InterfaceIndex           : 109
IPAddress                : 192.168.120.1
PreferredLifetime        : 10675199.02:48:05.4775807
PrefixOrigin             : Manual
SkipAsSource             : False
Store                    : ActiveStore
SuffixOrigin             : Manual
Type                     : Unicast
ValidLifetime            : 10675199.02:48:05.4775807
PSComputerName           : 
ifIndex                  : 109

IPv4Address              : 192.168.120.1
IPv6Address              : 
IPVersionSupport         : 
PrefixLength             : 24
SubnetMask               : 
AddressFamily            : IPv4
AddressState             : Invalid
InterfaceAlias           : vEthernet (myNAT)
InterfaceIndex           : 109
IPAddress                : 192.168.120.1
PreferredLifetime        : 10675199.02:48:05.4775807
PrefixOrigin             : Manual
SkipAsSource             : False
Store                    : PersistentStore
SuffixOrigin             : Manual
Type                     : Unicast
ValidLifetime            : 10675199.02:48:05.4775807
PSComputerName           : 
ifIndex                  : 109

Caption                          : 
Description                      : 
ElementName                      : 
InstanceID                       : myNAT;0
Active                           : True
ExternalIPInterfaceAddressPrefix : 
IcmpQueryTimeout                 : 30
InternalIPInterfaceAddressPrefix : 192.168.120.0/24
InternalRoutingDomainId          : {00000000-0000-0000-0000-000000000000}
Name                             : myNAT1
Store                            : Local
TcpEstablishedConnectionTimeout  : 1800
TcpFilteringBehavior             : AddressDependentFiltering
TcpTransientConnectionTimeout    : 120
UdpFilteringBehavior             : AddressDependentFiltering
UdpIdleSessionTimeout            : 120
UdpInboundRefresh                : False
PSComputerName                   : 

IP address "192.168.120.1" for static IP configuration already registered; skipping
"192.168.120.0/24" for static IP configuration already registered; skipping
```
Also there is a handy PowerShell [script](https://github.com/robertluwang/hands-on-nativecloud/blob/main/src/k8s-cri-dockerd/myNAT-delete.ps1) to delete hyper-v switch myNAT, vNIC and associated NAT, in case tear down NAT switch or reset it.
`myNAT-delete.ps1`

```
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
```

## Bring up static host-only ip with Vagrant 
Until now the Vagrant not supports well with Hyper-V network configuration like Virtualbox in Vagrantfile.

https://developer.hashicorp.com/vagrant/docs/providers/hyperv/limitations

host-only NIC for Virtualbox,
```
        vm.network :private_network, ip: "192.168.99.30"
```

then what should we do in hyper-v Vagrantfile? we only can choice network switcher, not chance to assign static ip.

Good news is that Vagrant can ssh to new launched vm via ipv6 IP, means we have chance to run any provision script, so as remedy we can run a shell inline or offline in provision stage, to setup static ip to eth0 manually, also correct /etc/resolv.conf for DNS setting.

Here is sample to launch Ubuntu 22.04 vm with 192.168.120.20 with Vagrant, to demo how static ip setup works for Ubuntu vm using [Vagrantfile](https://github.com/robertluwang/hands-on-nativecloud/blob/main/src/k8s-cri-dockerd/Vagrantfile.ub22hpv).
```
oldhorse@wsl2:$ cat Vagrantfile
$nic = <<SCRIPT

echo === $(date) Provisioning - nic $1 by $(whoami) start

SUBNET=$(echo $1 | cut -d"." -f1-3)

cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      dhcp6: no
      addresses: [$1/24]
      routes:
      - to: default
        via: ${SUBNET}.1
      nameservers:
        addresses: [8.8.8.8,1.1.1.1]
EOF

sudo unlink /etc/resolv.conf
sudo rm /etc/resolv.conf
cat << EOF | sudo tee /etc/resolv.conf
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

sudo chattr +i /etc/resolv.conf

cat /etc/netplan/01-netcfg.yaml
cat /etc/resolv.conf

sudo netplan apply
sleep 30 
echo eth0 setting

ip addr
ip route
ping -c 2 google.ca

echo === $(date) Provisioning - nic $1 by $(whoami) end
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2204"
  config.vm.provision "shell", inline: "sudo timedatectl set-timezone America/Montreal", privileged: false, run: "always"
  config.ssh.insert_key = false
  config.vm.box_check_update = false
  config.vm.network "public_network", bridge: "myNAT"

  config.vm.define "master" do |master|
      master.vm.hostname = "ub22hpv"
      master.vm.provider "hyperv" do |v|
          v.vmname = "ub22hpv"
          v.memory = 1024
      end
      master.vm.provision "shell", inline: $nic, args: "192.168.120.20", privileged: false
  end
end
```
We can see vagrant trying to ssh to vm via ipv6 with private key, 
```
    master: SSH address: fe80::215:5dff:fec9:606c:22
    master: SSH username: vagrant
    master: SSH auth method: private key
```
Full vagrant up log as below, 
```
oldhorse@wsl2: vagrant.exe up
Bringing machine 'master' up with 'hyperv' provider...
==> master: Verifying Hyper-V is enabled...
==> master: Verifying Hyper-V is accessible...
==> master: Importing a Hyper-V instance
    master: Creating and registering the VM...
    master: Successfully imported VM
    master: Configuring the VM...
    master: Setting VM Enhanced session transport type to disabled/default (VMBus)
==> master: Starting the machine...
==> master: Waiting for the machine to report its IP address...
    master: Timeout: 120 seconds
    master: IP: fe80::215:5dff:fec9:606c
==> master: Waiting for machine to boot. This may take a few minutes...
    master: SSH address: fe80::215:5dff:fec9:606c:22
    master: SSH username: vagrant
    master: SSH auth method: private key
==> master: Machine booted and ready!
==> master: Setting hostname...
==> master: Running provisioner: shell...
    master: Running: inline script
==> master: Running provisioner: shell...
    master: Running: inline script
    master: === Sun Apr 21 05:36:13 PM EDT 2024 Provisioning - nic 192.168.120.20 by vagrant start
    master: network:
    master:   version: 2
    master:   renderer: networkd
    master:   ethernets:
    master:     eth0:
    master:       dhcp4: no
    master:       dhcp6: no
    master:       addresses: [192.168.120.20/24]
    master:       routes:
    master:       - to: default
    master:         via: 192.168.120.1
    master:       nameservers:
    master:         addresses: [8.8.8.8,1.1.1.1]
    master: rm: cannot remove '/etc/resolv.conf': No such file or directory
    master: nameserver 8.8.8.8
    master: nameserver 1.1.1.1
    master: network:
    master:   version: 2
    master:   renderer: networkd
    master:   ethernets:
    master:     eth0:
    master:       dhcp4: no
    master:       dhcp6: no
    master:       addresses: [192.168.120.20/24]
    master:       routes:
    master:       - to: default
    master:         via: 192.168.120.1
    master:       nameservers:
    master:         addresses: [8.8.8.8,1.1.1.1]
    master: nameserver 8.8.8.8
    master: nameserver 1.1.1.1
    master: 
    master: ** (generate:3029): WARNING **: 17:36:14.124: Permissions for /etc/netplan/00-installer-config.yaml are too open. Netplan configuration should NOT be accessible by others.
    
    master: eth0 setting
    master: 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    master:     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    master:     inet 127.0.0.1/8 scope host lo
    master:        valid_lft forever preferred_lft forever
    master: 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    master:     link/ether 00:15:5d:c9:60:6c brd ff:ff:ff:ff:ff:ff
    master:     inet 192.168.120.20/24 brd 192.168.120.255 scope global eth0
    master:        valid_lft forever preferred_lft forever
    master:     inet6 fe80::215:5dff:fec9:606c/64 scope link
    master:        valid_lft forever preferred_lft forever
    master: default via 192.168.120.1 dev eth0 proto static
    master: 192.168.120.0/24 dev eth0 proto kernel scope link src 192.168.120.20
    master: PING google.ca (142.250.65.163) 56(84) bytes of data.
    master: 64 bytes from lga25s71-in-f3.1e100.net (142.250.65.163): icmp_seq=1 ttl=105 time=30.8 ms
    master: 64 bytes from lga25s71-in-f3.1e100.net (142.250.65.163): icmp_seq=2 ttl=105 time=69.3 ms
    master:
    master: --- google.ca ping statistics ---
    master: 2 packets transmitted, 2 received, 0% packet loss, time 1004ms
    master: rtt min/avg/max/mdev = 30.791/50.024/69.258/19.233 ms
    master: === Sun Apr 21 05:36:45 PM EDT 2024 Provisioning - nic 192.168.120.20 by vagrant end
```

## Build up k8s cluster with Hyper-V using Vagrant

After we make hyper-v vm with static ip works, then it is possible to install Docker, k8s package and build up k8s cluster via provision inline script.

We assume it is 2 nodes k8s cluster:
- Ubuntu 22.04 
- master: 2GB RAM 1 cpu  192.168.120.20
- worker: 1GB RAM 1 cpu  192.168.120.30 
- Docker: latest version 
- k8s: latest version , it is 1.30 here 

It spent around 26 mins to build up k8s 2 nodes cluster very smoothly, 

```
oldhorse@wsl2: date; vagrant.exe up ; date 
Sun Apr 21 18:05:06 EDT 2024
Bringing machine 'master' up with 'hyperv' provider...
Bringing machine 'worker' up with 'hyperv' provider...
...
master: kubeadm join 192.168.120.20:6443 --token y10r7h.1vycfilas9kpovzp \
    master:     --discovery-token-ca-cert-hash sha256:64e627afc4ed15beb607adf4073ae856400097fb4fed248094fb679e235cc597
  
...
worker: This node has joined the cluster:
worker: * Certificate signing request was sent to apiserver and a response was received.
...
Sun Apr 21 18:31:33 EDT 2024
```
check k8s cluster, it is running as 2 nodes cluster.

We can ssh to master vm using vagrant, or directly ssh to 192.168.120.20 master and 192.168.120.30 worker.

```
vagrant ssh master
```

It looks good, 

```
vagrant@master:~$ k get node
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   31m   v1.30.0
worker   Ready    <none>          19m   v1.30.0
vagrant@master:~$ k get pod -A
NAMESPACE          NAME                                       READY   STATUS    RESTARTS   AGE
calico-apiserver   calico-apiserver-7868f6b748-glqdx          1/1     Running   0          11m
calico-apiserver   calico-apiserver-7868f6b748-kc4gq          1/1     Running   0          11m
calico-system      calico-kube-controllers-78788579b8-vvrdh   1/1     Running   0          30m
calico-system      calico-node-dlrs8                          1/1     Running   0          19m
calico-system      calico-node-vvxm6                          1/1     Running   0          30m
calico-system      calico-typha-65bf4f686-mlpbx               1/1     Running   0          30m
kube-system        coredns-76f75df574-65mk8                   1/1     Running   0          31m
kube-system        coredns-76f75df574-z982z                   1/1     Running   0          31m
kube-system        etcd-master                                1/1     Running   0          31m
kube-system        kube-apiserver-master                      1/1     Running   0          31m
kube-system        kube-controller-manager-master             1/1     Running   0          31m
kube-system        kube-proxy-dcfcc                           1/1     Running   0          19m
kube-system        kube-proxy-x7qtl                           1/1     Running   0          31m
kube-system        kube-scheduler-master                      1/1     Running   0          31m
tigera-operator    tigera-operator-6fbc4f6f8d-h5wcm           1/1     Running   0          

vagrant@master:~$ k run test --image=nginx $do 
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: test
  name: test
spec:
  containers:
  - image: nginx
    name: test
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

vagrant@master:~$ k run test --image=nginx 
pod/test created
vagrant@master:~$ k get pod 
NAME   READY   STATUS              RESTARTS   AGE
test   0/1     ContainerCreating   0          4s

vagrant@master:~$ k get pod -o wide
NAME   READY   STATUS    RESTARTS   AGE   IP               NODE     NOMINATED NODE   READINESS GATES
test   1/1     Running   0          42s   192.168.171.67   worker   <none>           <none>

vagrant@master:~$ curl 192.168.171.67
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
</html>

```
## k8s setup tool set
In above example, we demo the quick way to launch k8s cluster using Vagrant, which uses inline scripts to install docker, setup cri-dockerd, install k8s packages, init k8s cluster or join to cluster on worker node.

In fact we can use scripts for handy setup k8s cluster when you already have running Linux node, no matter it is physical Linux, Linux vm, or WSL2.

Just run script as sudo user,

`master node`

```
docker-server.sh
k8s-install.sh
cri-dockerd.sh
k8s-init.sh "192.168.120.20"
```
`worker node`
```
docker-server.sh
k8s-install.sh
cri-dockerd.sh
k8s-join-worker.sh "192.168.120.20"
```
## Conclusion
We make the k8s 2 nodes cluster setup automation smoothly using Vagrant:

- it is possible to make k8s cluster setup on Hyper-V full automatically 
- it is ideal local k8s lab for production like testing and education

## About Me

Hey! I am Robert Wang, live in Montreal.

More simple and more efficient.

- [GitHub: robertluwang](https://github.com/robertluwang)
- [Twitter: robertluwang](https://twitter.com/robertluwang)
- [LinkedIn: robertluwang](https://www.linkedin.com/in/robertluwang/) 
- [Medium: robertluwang](https://medium.com/@robertluwang)
- [Dev.to: robertluwang](https://dev.to/robertluwang)
- [Web: dreamcloud.artark.ca](https://dreamcloud.artark.ca)
