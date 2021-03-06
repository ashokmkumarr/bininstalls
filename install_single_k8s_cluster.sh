#!/bin/bash
echo "--------------------------------------------------------------------------------------------------"
echo "Verifying whether docker and kubenetes is installed in the system"
echo "--------------------------------------------------------------------------------------------------"
docker_v=$(docker -v)                           
echo "$docker_v"                                
docker_string_pattern="Docker version"          
if [[ $docker_v == *$docker_string_pattern* ]]  
then                                            
        echo "Docker installed"
else
        echo "Docker is not installed in the system. Please refer the logs"
        exit 1         
fi  

kubectl_v=$(kubectl version)
kubernets_string_pattern="Client Version"
if [[ $kubectl_v == *$kubernetes_string_pattern* ]]
then
        echo "Kuberetes installed in the system"
else
        echo "Kubernetes is not installed in the system"
fi

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
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml

echo "Verifying whether flannel pod is up and running"
SLEEP_TIME=60
for i in {1..5}                                                                  
do
        cmd=$(kubectl get pods -A --field-selector status.phase=Running | grep flannel)                                                                                
        if [[ $cmd == *"Running"* ]]                                             
        then                                                                     
                echo "flannel driver runs successfully"                          
                break
        else
                if [ $i == 5 ]
                then
                        echo "flannel driver is not running. Please verify the pod"          
                        break 
                fi            
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME                                                     
        fi                                                                       
done

echo "--------------------------------------------------------------------------------------------------"
echo "Check the status after about a minute and it should show as Ready"
echo "--------------------------------------------------------------------------------------------------"
kubectl get nodes
POD_COUNT_1=8
for i in {1..5}
do
        cmd1=$(kubectl get pods -n kube-system | grep -c Running)
        cmd2=$(kubectl -n kube-system get pods -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,PodIP:status.podIP,READY:status.containerStatuses[*].ready | grep -c true)

        if [[ $cmd1 == $POD_COUNT_1  && $cmd2 == $POD_COUNT_1 ]]
        then
                echo "All the kube-system pods are running and ready"
                break
        else
                if [ $i == 5 ]
                then
                        echo "All the kube-system pods are not running, Please verify the pods"  
                        echo "Exiting the script"                           
                        exit 1
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "--------------------------------------------------------------------------------------------------"
echo "Configuring master Node as a Worker by tainting the master node"
echo "--------------------------------------------------------------------------------------------------"
kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule-

cmd=$(kubeadm token create --print-join-command)
echo -e "Use the below command to join the worker node to master node:\n $cmd"