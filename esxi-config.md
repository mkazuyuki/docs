# ESXi configuration notes for ECX Host Clustering
- All the nodes in vMA Cluster and iSCSI Cluster should be configured to boot automatically when ESXi starts.
- The network for iSCSI and Data Mirroring should use physically indepenent netowrk if possible. Configure logically independent at least.
- Add VMkernel port for iSCSI communication.
- Try to invalidate TSO, LRO and Jumbo Frame if iSCSI performance is not enough.
- Configure ssh service to start automatically when ESXi start.


- genw-remote-node in vMA Cluster periodically executes "power on" for another vMA VM. And so, "suspend" the genw-remote-node before when intentionally shutdown the vMA VM
- genw-remote-node in vMA Cluster periodically executes "starting cluster service" for another vMA VM. And so, "suspend" the genw-remote-node before when intentionally stop the cluster service.


<!--
- vMA VM, iSCSI VM の自動起動設定
- iSCSI network と mirror network の分割
- iSCSI用 VMkernel port の追加
- TSO, LRO, Jumbo frame の無効化
- ssh サービスの自動起動設定
- vMA Cluster の genw-remote-node は
  - 対向 vMA VM の power off status を認識すると power on を実行する。従って、意図的に vMA VM を power off 状態にするときは、vMA Cluster の genw-remote-node を suspend する必要がある。
  - 対向 vMA VM で ECサービス の offline status を認識すると service start を実行する。従って、意図的に ECサービス を offline status にするときは、vMA Cluster の genw-remote-node を suspend する必要がある。
-->
