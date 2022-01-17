#!/bin/bash

SLEEP_TIME=60

echo "Verifying pre-checks before installing voltha"
cmd=$(lscpu | grep '^CPU(s):' | tr -s ' ' | awk '{ print $2; }')
echo "$cmd"
if [ "$cmd" -ge 80 ]
then
        echo "CPU is more than 8 cores"
else
        echo "Please ensure that CPU is more than 8 cores"
        exit 1
fi

echo "Installing helm"
sudo snap install helm --classic

echo "Adding helm repo - https://charts.opencord.org"
helm repo add onf https://charts.opencord.org
helm repo update

echo "Creating voltha infra pods"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra

echo "Waiting for the voltha infra pods to be up and running"
cmd=$(kubectl get pods -n infra | grep -c Running)

for i in {1..5}
do
        if [[ $cmd == 7 ]]
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

echo "Adding tracing and kibana pods to infra"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra --set voltha-tracing.enabled=true --set efk.enabled=true

echo "Waiting for the voltha infra pods to be up and running"
cmd=$(kubectl get pods -n infra | grep -c Running)
for i in {1..5}
do
        if [[ $cmd == 11 ]]
        then
                echo "All the infra objects are running"
                break
        else
                if [ $i == 5 ]
                the
                        echo "All the infra objects are not running, Please verify the pods"  
                        echo "Exiting the script"                           
                        exit 1
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "Port forwarding"
kubectl -n infra port-forward --address 0.0.0.0 svc/voltha-infra-onos-classic-hs 8101:8101 &
kubectl -n infra port-forward --address 0.0.0.0 svc/voltha-infra-onos-classic-hs 8181:8181 &
kubectl port-forward -n infra --address 0.0.0.0 svc/voltha-infra-voltha-tracing-jaeger-gui 16686 &
kubectl port-forward -n infra --address 0.0.0.0 svc/voltha-infra-kibana 5601 &

curl -v -X POST -H Content-type:application/json -H kbn-xsrf:true http://localhost:5601/api/saved_objects/index-pattern/logst* -d '{"attributes":{"title":"logst*","timeFieldName":"@timestamp"}}'

echo "Deploying VOLTHA"
helm upgrade --install --create-namespace -n voltha voltha onf/voltha-stack --set global.stack_name=voltha --set global.voltha_infra_name=voltha-infra --set global.voltha_infra_namespace=infra --set global.tracing.enabled=true --set global.log_correlation.enabled=true
echo "Waiting for the voltha pods to be up and running"
cmd=$(kubectl get pods -n voltha | grep -c Running)
for i in {1..5}
do
        if [[ $cmd == 4 ]]
        then
                echo "All the voltha pods are running"
                break
        else
                if [ $i == 5 ]
                the
                        echo "All the voltha pods are not running, Please verify the pods" 
                        echo "Exiting the script"                            
                        exit 1 
                fi
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "Deploying BBsim - broadband simulator"
helm upgrade --install -n voltha bbsim0 onf/bbsim --set olt_id=10

