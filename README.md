B
# System initialization

Follow PRE_INSTALL.sh script to generate initial system

It will provide a system with:
 * full-disk encryption using LVM on LUKS
 * UEFI boot loader
 * ansible

You should have configure your system in UEFI mode.

# Launch Ansible
Ansible has been installed in previous step.
We need to configure it
```bash
mkdir -p /etc/ansible
cp etc-ansible-hosts /etc/ansible/hosts
ansible-playbook xps13.yml --ask-sudo-pass
```
