#!/bin/bash
echo "--------------------------------------------------------------------------------------------------"
echo "Initializing k8s cluster"
echo "--------------------------------------------------------------------------------------------------"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

echo "--------------------------------------------------------------------------------------------------"
echo "Set up the kubeconfig"
echo "--------------------------------------------------------------------------------------------------"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
cat ~/.kube/config

echo "--------------------------------------------------------------------------------------------------"
echo "Get the status of the nodes"
echo "--------------------------------------------------------------------------------------------------"
kubectl get nodes
kubectl describe nodes

echo "--------------------------------------------------------------------------------------------------"
echo "Install the Network plugin - flannel"
echo "--------------------------------------------------------------------------------------------------"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
<< EOF
echo "--------------------------------------------------------------------------------------------------"
echo "Check the status after about a minute and it should show as Ready"
echo "--------------------------------------------------------------------------------------------------"
kubectl get nodes
EOF