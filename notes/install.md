Follow KMS guide, Vault storage and encryption managed by OCI platform.

Oracle Linux 9 - Latest Image, smalled x64 vm and 2 OCPU ARM.

50G block volume, AD3, attach to arm instance, run some iscsi commands, comes up as sdb.
LVM on it, fresh vg called storage, lv called volumes
mount to /volumes on ARM vm, use _netdev option

https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install

Install VAULT and Nomad (not using Conusl, etc at this stage.) on both machines

install dnf automatic

apply-updates = yes
reboot = when-needed

enable dnf-automatic.timer

configure vault with OCI seal and storage

generate initial certificates.
