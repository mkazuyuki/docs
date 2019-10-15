# Howto setup vMA Cluster on EXPRESSCLUSTER for Linux

This guide provides how to create Management VM Cluster on EXPRESSCLUSTER for Linux.


## Versions
- VMware vSphere Hypervisor 6.7U2 (VMware ESXi 6.7U2)
- CentOS 7.6 x86_64
- vSphere Command Line Interface 6.7
- EXPRESSCLUSTER X for Linux 4.1.1-1

## Network configuration
![Network configuraiton](HAUC-NW-Configuration.png)

## Nodes configuration

|Virtual HW	|Number, Amount	|
|:--		|:---		|
| vCPU		| 2 CPU		| 
| Memory	| 4 GB		|
| vNIC		| 1 port	|
| vHDD		| 6 GB		|

|		| Primary		| Secondary		|
|---		|---			|---			|
| Hostname	| vma1			| vma2			|
| IP Address	| 172.31.255.6/24	| 172.31.255.7/24	|

## Overall Setup Procedure
- Creating VMs (*vma1* and *vma2*) one on each ESXi
- Install CentOS, vCLI and EC on them.

## Procedure

### Creating VMs on both ESXi

- Download CetOS 7.6 (CentOS-7-x86_64-Minimal-1810.iso) and put it on /vmfs/volumes/datastore1/iso of esxi1 and esxi2.

- Run the below script

  - on esxi1

		#!/bin/sh -ue

		# (0) Parameters
		DATASTORE_PATH=/vmfs/volumes/datastore1
		ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-Minimal-1810.iso
		VM_NAME=vMA1
		VM_CPU_NUM=2
		VM_MEM_SIZE=4096
		VM_NETWORK_NAME1="VM Network"
		VM_GUEST_OS=centos7-64
		VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
		VM_DISK_SIZE=6g

		VM_DISK_PATH=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmdk
		VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

		# (1) Create dummy VM
		VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`

		# (2) Edit vmx file
		sed -i -e '/^guestOS /d' $VM_VMX_FILE
		cat << __EOF__ >> $VM_VMX_FILE
		guestOS = "$VM_GUEST_OS"
		numvcpus = "$VM_CPU_NUM"
		memSize = "$VM_MEM_SIZE"
		ethernet0.virtualDev = "vmxnet3"
		ethernet0.present = "TRUE"
		ethernet0.networkName = "$VM_NETWORK_NAME1"
		ethernet0.addressType = "generated"
		ethernet0.wakeOnPcktRcv = "FALSE"
		ide0:0.present = "TRUE"
		ide0:0.deviceType = "$VM_CDROM_DEVICETYPE"
		ide0:0.fileName = "$ISO_FILE"
		__EOF__

		# (3) Extend disk size
		vmkfstools -X $VM_DISK_SIZE $VM_DISK_PATH 

		# (4) Reload VM information
		vim-cmd vmsvc/reload $VM_ID

  - on esxi2

		#!/bin/sh -ue

		# (0) Parameters
		DATASTORE_PATH=/vmfs/volumes/datastore1
		ISO_FILE=/vmfs/volumes/datastore1/iso/CentOS-7-x86_64-Minimal-1810.iso
		VM_NAME=vMA2
		VM_CPU_NUM=2
		VM_MEM_SIZE=4096
		VM_NETWORK_NAME1="VM Network"
		VM_GUEST_OS=centos7-64
		VM_CDROM_DEVICETYPE=cdrom-image  # cdrom-image / atapi-cdrom
		VM_DISK_SIZE=6g

		VM_DISK_PATH=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmdk
		VM_VMX_FILE=$DATASTORE_PATH/$VM_NAME/$VM_NAME.vmx

		# (1) Create dummy VM
		VM_ID=`vim-cmd vmsvc/createdummyvm $VM_NAME $DATASTORE_PATH`

		# (2) Edit vmx file
		sed -i -e '/^guestOS /d' $VM_VMX_FILE
		cat << __EOF__ >> $VM_VMX_FILE
		guestOS = "$VM_GUEST_OS"
		numvcpus = "$VM_CPU_NUM"
		memSize = "$VM_MEM_SIZE"
		ethernet0.virtualDev = "vmxnet3"
		ethernet0.present = "TRUE"
		ethernet0.networkName = "$VM_NETWORK_NAME1"
		ethernet0.addressType = "generated"
		ethernet0.wakeOnPcktRcv = "FALSE"
		ide0:0.present = "TRUE"
		ide0:0.deviceType = "$VM_CDROM_DEVICETYPE"
		ide0:0.fileName = "$ISO_FILE"
		__EOF__

		# (3) Extend disk size
		vmkfstools -X $VM_DISK_SIZE $VM_DISK_PATH 

		# (4) Reload VM information
		vim-cmd vmsvc/reload $VM_ID

- Boot vMA1 and vMA2 and install CentOS

- Configure hostname, IP address, firewall, selinux, ssh

  vMA1, 2 need to be accessible to the internet during the setup.
  In the following, *ens160* assumes to be connected to *VM Network* port group and obtain network configuration from DHCP server.
  When DHCP is abscent, use *nmtui* command or edit /etc/sysconfig/network-scripts/ifcfg-ens160 so that can access the Internet.

  - on vma1

		ifup ens160
		hostnamectl set-hostname vma1
		systemctl stop firewalld.service
		systemctl disable firewalld.service
		sed -i -e 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
		ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
		reboot

  - on vma2

		ifup ens160
		hostnamectl set-hostname vma2
		systemctl stop firewalld.service
		systemctl disable firewalld.service
		sed -i -e 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
		ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
		reboot

- Install vCLI

  - Download vCLI package and install according to its document
  	- package : [VMware-vSphere-CLI-6.7.0-8156551.x86_64.tar.gz](https://code.vmware.com/web/tool/6.7/vsphere-cli )
  	
	- document : https://code.vmware.com/docs/6526/getting-started-with-vsphere-command-line-interfaces

      in the above URL there is [the document for installation](https://code.vmware.com/docs/6526/getting-started-with-vsphere-command-line-interfaces#/doc/GUID-38C02094-CEE2-469E-8FB9-5453DA416623.html).  

      <!--
      As supplemental, refer to the document [howto-make-vma-vm](https://github.com/mkazuyuki/docs/blob/master/etc/howto-make-vma-vm.md).
      -->

  - Login to the vMA1, 2 with root user. Bring up the NIC.

		# ifup ens160

  <!--
  - If proxy server is required for accessing the internet

	# export http_proxy=http://YOUR_PROXY_HOST:PORT
	# export ftp_proxy=http://YOUR_PROXY_HOST:PORT
  -->

  - Setup accessing EPEL package repository

		# yum -y install epel-release
		# sed -i "s/metalink=https/metalink=http/" /etc/yum.repos.d/epel.repo

  - Install packages required for vCLI

		yum -y install e2fsprogs-devel libuuid-devel openssl-devel perl-devel
		yum -y install glibc.i686 zlib.i686 gcc
		yum -y install perl-XML-LibXML libncurses.so.5 perl-Crypt-SSLeay
		yum -y install perl-Time-Piece perl-Archive-Zip perl-Try-Tiny perl-Socket6 perl-YAML
		yum -y install perl-Path-Class perl-Text-Template perl-Net-INET6Glue perl-version
		yum -y install perl-CPAN

  - Run *cpan* to install perl modules

		# cpan
		:
		[yes]
		:
		[local::lib]
		:
		[yes]
		:

  - You will see the following error then back to shell prompt. Refer to [VMmware KB 2038990](https://kb.vmware.com/s/article/2033341) about the error. 

		Can't call method "http" on unblessed reference at /usr/share/perl5/CPAN/FirstTime.pm line 1866.

  - Do the followings for fixing *FirstTime.pm*. 

		# curl -O http://cpan.metacpan.org/authors/id/A/AN/ANDK/CPAN-2.27.tar.gz
		# tar xzvf CPAN-2.27.tar.gz
		# cp CPAN-2.27/lib/CPAN/FirstTime.pm /usr/share/perl5/CPAN/FirstTime.pm

  - Run *cpan* command and make default answers for the prompts. Then you reach to cpan prompt, Input following commands.

		# cpan
		:
		cpan[1]> o conf prerequisites_policy follow
		cpan[2]> o conf commit
		cpan[3]> install Devel::CheckLib
		cpan[4]> q

		# cpan
		cpan[1]> install UUID
		cpan[2]> install LWP::Protocol::https
		cpan[3]> q

  - Put vCLI package on the server then install it.

		# tar xzvf VMware-vSphere-CLI-6.7.0-8156551.x86_64.tar.gz
		# ./vmware-vsphere-cli-distrib/vmware-install.pl

- Install EC
  - Login to vma1 and vma2 then execute following commands.
  - Download, unzip, install the packeage then install the license 

		# curl -O https://www.nec.com/en/global/prod/expresscluster/en/trial/zip/ecx41l_x64.zip
		# yum install unzip
		# unzip ecx411_x64.zip
		# rpm -ivh ecx41l_x64/Linux/4.1/en/server/expresscls-4.1.1-1.x86_64.rpm
		# clplcnsc -I [YOUR_LICENSE_FILE]
		
  - Delete unnecessary files

		# rm -rf ecx41l_x64/ ecx41l_x64.zip

- Install VMware Tools

		# yum install open-vm-tools

- Reconfigure IP address

  - on vma1

		# nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.6/24 connection.autoconnect yes
		# systemctl restart network

  - on vma2

		# nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.7/24 connection.autoconnect yes
		# systemctl restart netwrok

## Revision history
2017.02.03	Miyamoto Kazuyuki	1st issue  
2019.06.27	Miyamoto Kazuyuki	2nd issue
