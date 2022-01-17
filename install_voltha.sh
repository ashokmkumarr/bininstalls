#!/bin/bash

SLEEP_TIME=60
echo "--------------------------------------------------------------------------------------------------"
echo "Verifying pre-checks before installing voltha"
echo "--------------------------------------------------------------------------------------------------"
cmd=$(lscpu | grep '^CPU(s):' | tr -s ' ' | awk '{ print $2; }')
if [ "$cmd" -ge 8 ]
then
        echo "CPU is greater than equal to 8 cores"
else
        echo "Please ensure that CPU is not equal to or more than 8 cores"
        exit 1
fi
echo "--------------------------------------------------------------------------------------------------"
echo "Installing helm and adding helm repo"
echo "--------------------------------------------------------------------------------------------------"
sudo snap install helm --classic
echo "Adding helm repo - https://charts.opencord.org"
helm repo add onf https://charts.opencord.org
helm repo update

echo "--------------------------------------------------------------------------------------------------"
echo "Creating voltha infra pods"
echo "--------------------------------------------------------------------------------------------------"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra

echo "--------------------------------------------------------------------------------------------------"
echo "Waiting for the voltha infra pods to be up and running"
echo "--------------------------------------------------------------------------------------------------"
POD_COUNT_1=7
for i in {1..10}
do
        cmd1=$(kubectl get pods -n infra | grep -c Running)
        cmd2=$(kubectl -n infra get pods -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,PodIP:status.podIP,READY:status.containerStatuses[*].ready | grep -c true)
        if [[ $cmd1 == $POD_COUNT_1  && $cmd2 == $POD_COUNT_1 ]]
        then
                echo "All the infra objects are running"
                break
        else
                if [ $i == 5 ]
                then
                        echo "All the infra objects are not running, Please verify the pods" 
                        echo "Exiting the script"         
                        exit 1
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "--------------------------------------------------------------------------------------------------"
echo "Adding tracing and kibana pods to infra"
echo "--------------------------------------------------------------------------------------------------"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra --set voltha-tracing.enabled=true --set efk.enabled=true

echo "--------------------------------------------------------------------------------------------------"
echo "Waiting for the voltha infra pods to be up and running"
echo "--------------------------------------------------------------------------------------------------"
POD_COUNT_2=11
for i in {1..5}
do
        cmd1=$(kubectl get pods -n infra | grep -c Running)
        cmd2=$(kubectl -n infra get pods -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,PodIP:status.podIP,READY:status.containerStatuses[*].ready | grep -c true)
        if [[ $cmd1 == $POD_COUNT_2  && $cmd2 == $POD_COUNT_2 ]]
        then
                echo "All the infra objects are running"
                break
        else
                if [ $i == 5 ]
                then
                        echo "All the infra objects are not running, Please verify the pods"  
                        echo "Exiting the script"                           
                        exit 1
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "--------------------------------------------------------------------------------------------------"
echo "Port forwarding to expose ONOS CLI(Port:8101), ONOS API(Port:8181), Kibana(Port:5601)"
echo "--------------------------------------------------------------------------------------------------"
kubectl -n infra port-forward --address 0.0.0.0 svc/voltha-infra-onos-classic-hs 8101:8101 &
kubectl -n infra port-forward --address 0.0.0.0 svc/voltha-infra-onos-classic-hs 8181:8181 &
kubectl port-forward -n infra --address 0.0.0.0 svc/voltha-infra-voltha-tracing-jaeger-gui 16686 &
kubectl port-forward -n infra --address 0.0.0.0 svc/voltha-infra-kibana 5601 &

curl -v -X POST -H Content-type:application/json -H kbn-xsrf:true http://localhost:5601/api/saved_objects/index-pattern/logst* -d '{"attributes":{"title":"logst*","timeFieldName":"@timestamp"}}'

echo "--------------------------------------------------------------------------------------------------"
echo "Deploying VOLTHA"
echo "--------------------------------------------------------------------------------------------------"
helm upgrade --install --create-namespace -n voltha voltha onf/voltha-stack --set global.stack_name=voltha --set global.voltha_infra_name=voltha-infra --set global.voltha_infra_namespace=infra --set global.tracing.enabled=true --set global.log_correlation.enabled=true
echo "--------------------------------------------------------------------------------------------------"
echo "Waiting for the voltha pods to be up and running"
echo "--------------------------------------------------------------------------------------------------"
POD_COUNT_3=4
for i in {1..5}
do
        cmd1=$(kubectl get pods -n voltha | grep -c Running)
        cmd2=$(kubectl -n voltha get pods -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,PodIP:status.podIP,READY:status.containerStatuses[*].ready | grep -c true)
        if [[ $cmd1 == $POD_COUNT_3  && $cmd2 == $POD_COUNT_3 ]]
        then
                echo "All the voltha pods are running"
                break
        else
                if [ $i == 5 ]
                then
                        echo "All the voltha pods are not running, Please verify the pods" 
                        echo "Exiting the script"                            
                        exit 1 
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "--------------------------------------------------------------------------------------------------"
echo "Deploying BBsim - broadband simulator"
echo "--------------------------------------------------------------------------------------------------"
helm upgrade --install -n voltha bbsim0 onf/bbsim --set olt_id=10

echo "--------------------------------------------------------------------------------------------------"
echo "Waiting for the BBsim pods to be up and running"
echo "--------------------------------------------------------------------------------------------------"
POD_COUNT_4=5
for i in {1..5}
do
        cmd1=$(kubectl get pods -n voltha | grep -c Running)
        cmd2=$(kubectl -n voltha get pods -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,PodIP:status.podIP,READY:status.containerStatuses[*].ready | grep -c true)
        if [[ $cmd1 == $POD_COUNT_4  && $cmd2 == $POD_COUNT_4 ]]
        then
                echo "All the voltha pods are running"
                break
        else
                if [ $i == 5 ]
                then
                        echo "All the voltha pods are not running, Please verify the pods" 
                        echo "Exiting the script"                            
                        exit 1 
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "--------------------------------------------------------------------------------------------------"
echo "Port forwarding to expose voltha-api using port 55555"
kubectl -n voltha port-forward svc/voltha-voltha-api 55555 &
echo "--------------------------------------------------------------------------------------------------"

echo "--------------------------------------------------------------------------------------------------"
echo "Installing voltctl"
echo "--------------------------------------------------------------------------------------------------"
HOSTOS="$(uname -s | tr "[:upper:]" "[:lower:"])"
HOSTARCH="$(uname -m | tr "[:upper:]" "[:lower:"])"
if [ "$HOSTARCH" == "x86_64" ]; then
    HOSTARCH="amd64"
fi
sudo wget https://github.com/opencord/voltctl/releases/download/v1.3.1/voltctl-1.3.1-$HOSTOS-$HOSTARCH -O /usr/local/bin/voltctl
sudo chmod a+x /usr/local/bin/voltctl
source <(voltctl completion bash)

echo "--------------------------------------------------------------------------------------------------"
echo "Installing nginix Ingress controller"
echo "--------------------------------------------------------------------------------------------------"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra --set etcd.ingress.enabled=true
helm upgrade --install --create-namespace -n voltha voltha onf/voltha-stack --set voltha.ingress.enabled=true

echo "--------------------------------------------------------------------------------------------------"
echo "Waiting for the voltha pods to be up and running"
echo "--------------------------------------------------------------------------------------------------"
POD_COUNT_4=5
for i in {1..5}
do
        cmd1=$(kubectl get pods -n voltha | grep -c Running)
        cmd2=$(kubectl -n voltha get pods -o custom-columns=NAMESPACE:metadata.namespace,POD:metadata.name,PodIP:status.podIP,READY:status.containerStatuses[*].ready | grep -c true)
        if [[ $cmd1 == $POD_COUNT_4  && $cmd2 == $POD_COUNT_4 ]]
        then
                echo "All the voltha pods are running"
                break
        else
                if [ $i == 5 ]
                then
                        echo "All the voltha pods are not running, Please verify the pods" 
                        echo "Exiting the script"                            
                        exit 1 
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "--------------------------------------------------------------------------------------------------"
echo "Creating adapter and devices"
echo "--------------------------------------------------------------------------------------------------"
kubectl -n voltha port-forward svc/voltha-voltha-api 55555 &
voltctl device create -t openolt -H bbsim0.voltha.svc:50060

kubectl -n voltha port-forward svc/voltha-voltha-api 55555 &
voltctl device list --filter Type~openolt -q | xargs voltctl device enable

echo "Show adapter list"
voltctl adapter list

echo "Verifying whether the adapters is created"
SLEEP_TIME=30
for i in {1..3}
do
        cmd1=$(voltctl adapter list | grep -c openolt)
        cmd2=$(voltctl adapter list | grep -c openomci)
        if [[ $cmd1 == 1  && $cmd2 == 1 ]]
        then
                echo "Adapters for openolt and openomci are created successfully"
        else
                if [ $i == 3 ]
                then
                        echo "Adapters are not created succssfully"
                        echo "$(voltctl adapter list)"
                        exit 1
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME
    fi
done

echo "Show device list"
voltctl device list

echo "Verifying whether the devices are created"

SLEEP_TIME=30
for i in {1..3}
do
        cmd=$(voltctl device list | grep -c ACTIVE)
        if [[ $cmd == 2 ]]
        then
                echo "Devices for openolt and openomci are created successfully"
        else
                if [ $i == 3 ]
                then
                        echo "Devices are not created succssfully"
                        echo "$(voltctl device list)"
                        exit 1
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME
    fi
done