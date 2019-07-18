# Howto install vCLI6.7 on CentOS6.6 behind firewall

## Do CentOS 6.6 Minimal Install then
```
ifup eth0
export http_proxy=http://PROXY_HOST:PORT
export ftp_proxy=http://PROXY_HOST:PORT

rpm -Uvh http://ftp.riken.jp/Linux/fedora/epel/6/x86_64/epel-release-6-8.noarch.rpm
sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo
yum install open-vm-tools openssh-clients e2fsprogs-devel libuuid-devel glibc.i686 perl-XML-LibXML openssl-devel gcc cpan perl-Time-Piece perl-Archive-Zip perl-Path-Class perl-Try-Tiny perl-Crypt-SSLeay perl-HTML-Parser perl-Socket6 perl-Text-Template perl-Net-INET6Glue perl-libwww-perl perl-YAML -y

perl -MCPAN -e shell
:
Would you like me to configure as much as possible automatically? [yes] yes
:
o conf prerequisites_policy follow
o conf commit
install UUID
install Test::More
install Date::Format
q
```

## Put vCLI package on the server then
```
tar xzvf VMware-vSphere-CLI-6.7.0-8156551.x86_64.tar.gz
./vmware-vsphere-cli-distrib/vmware-install.pl
ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
```

## Put ECX rpm and license file then
```
sed -i -e 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
rpm -ivh expresscls-4.1.1-1.x86_64.rpm
clplcnsc -i ECX4.x-lin1.key
```
