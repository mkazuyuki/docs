# Howto install vCLI 6.7 on CentOS 7.6


### Prerequisites

- VM with CentOS 7 installed.
- The VM is accessible to the internet.

### Procedure

Install CentOS and configure the network then login to the VM as root user.
Run followings.

	ifup ens160
	hostnamectl set-hostname vma1
	systemctl stop firewalld.service
	systemctl disable firewalld.service
	sed -i -e 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
	ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
	reboot

Login to the VM with root user. Preparing installation for vCLI

	ifup ens160

	# If proxy server is required for accessing the internet
	export http_proxy=http://YOUR_PROXY_HOST:PORT
	export ftp_proxy=http://YOUR_PROXY_HOST:PORT

	# Setup accessing EPEL repository
	yum -y install epel-release
	sed -i "s/metalink=https/metalink=http/" /etc/yum.repos.d/epel.repo

	# Install packages required for vCLI
	yum -y install e2fsprogs-devel libuuid-devel openssl-devel perl-devel
	yum -y install glibc.i686 zlib.i686 gcc
	yum -y install perl-XML-LibXML libncurses.so.5 perl-Crypt-SSLeay
	yum -y install perl-Time-Piece perl-Archive-Zip perl-Try-Tiny perl-Socket6 perl-YAML
	yum -y install perl-Path-Class perl-Text-Template perl-Net-INET6Glue perl-version
	yum -y install perl-CPAN


Run *cpan* to install perl modules

	# cpan
	:
	[yes]
	:
	[local::lib]
	:
	[yes]
	:

You will see the following error then back to shell prompt. 

	Can't call method "http" on unblessed reference at /usr/share/perl5/CPAN/FirstTime.pm line 1866.

Refer to [VMmware KB 2038990](https://kb.vmware.com/s/article/2033341). Then do the followings for fixing *FirstTime.pm*. 

	# curl -O http://cpan.metacpan.org/authors/id/A/AN/ANDK/CPAN-2.27.tar.gz
	# tar xzvf CPAN-2.27.tar.gz
	# cp CPAN-2.27/lib/CPAN/FirstTime.pm /usr/share/perl5/CPAN/FirstTime.pm

Run *cpan* command and make default answers for the prompts. Then you reach to cpan prompt, Input following commands.


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

Put vCLI package on the server then install it.

	# tar xzvf VMware-vSphere-CLI-6.7.0-8156551.x86_64.tar.gz
	# ./vmware-vsphere-cli-distrib/vmware-install.pl

Configure the NIC.

	# nmcli c m ens160 ipv4.method manual ipv4.addresses 172.31.255.6/24 connection.autoconnect yes
