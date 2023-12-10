#!/bin/bash

USERNAME="haquocdat543"
REPONAME="jenkins-ansible"
exec > >(tee -i /var/log/user-data.log)
exec 2>&1
sudo apt update -y
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y
sudo apt install git -y 
mkdir Ansible && cd Ansible
pwd
git clone https://github.com/${USERNAME}/${REPONAME}.git   #change to your own repo
cd ${REPONAME}
ansible-playbook -i localhost Jenkins-playbook.yml

hostnamectl set-hostname Jenkins-Ansible 
