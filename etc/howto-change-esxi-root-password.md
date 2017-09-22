# Howto change root password of ESXi
- On vMA Cluster Manager, suspend the cluster.
- Change the root password of ESXi by any method.
- On vma1 and vma2 console,
  - Remove then add the root password by credstore_admin.pl

		> sudo bash
		# cd /usr/lib/vmware-vcli/apps/general
		# credstore_admin.pl remove -s 10.0.0.1 -u root
		New entry added successfully
		# credstore_admin.pl add -s 10.0.0.1 -u root -p 'new-passwd'
		New entry added successfully
		# exit
		>

- On vMA Cluster Manager, resume the cluster.
