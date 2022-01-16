#!/bin/bash
echo "--------------------------------------------------------------------------------------------------"
echo "Adding Dependencies"
echo "--------------------------------------------------------------------------------------------------"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update && sudo apt-get install -y apt-transport-https && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list && sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg]  https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "--------------------------------------------------------------------------------------------------"
echo "Swapoff permanantly"
echo "--------------------------------------------------------------------------------------------------"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "--------------------------------------------------------------------------------------------------"
echo "Installing docker binaries"
echo "--------------------------------------------------------------------------------------------------"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo docker --version

echo "--------------------------------------------------------------------------------------------------"
echo "Docker running status and making docker to run without using sudo"
echo "--------------------------------------------------------------------------------------------------"
sudo systemctl status docker --no-pager -l
sudo usermod -aG docker $USER
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker --no-pager -l
# newgrp docker 

echo "--------------------------------------------------------------------------------------------------"
echo "Making systemd as cgroup driver for docker"
echo "--------------------------------------------------------------------------------------------------"
mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json 
{ 
  "exec-opts": ["native.cgroupdriver=systemd"] 
} 
EOF

echo "--------------------------------------------------------------------------------------------------"
echo "Restarting docker service"
echo "--------------------------------------------------------------------------------------------------"
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker --no-pager -l
sudo apt-get update

echo "--------------------------------------------------------------------------------------------------"
echo "Installing k8s binaries"
echo "--------------------------------------------------------------------------------------------------"
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


echo "--------------------------------------------------------------------------------------------------"
echo "Get versions: Docker and kubernetes"
echo "--------------------------------------------------------------------------------------------------"
get_docker_version="docker -v"
echo "Docker version:$($get_docker_version)"

get_k8s_version="kubectl version"
echo "K8s version:$($get_k8s_version)"
