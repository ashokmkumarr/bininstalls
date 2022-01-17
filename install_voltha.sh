#!/bin/bash
echo "Installing helm"
sudo snap install helm --classic

echo "Adding helm repo - https://charts.opencord.org"
helm repo add onf https://charts.opencord.org
helm repo update

echo "Creating voltha infra pods"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra

echo "Waiting for the voltha infra pods to be up and running"
cmd=$(kubectl get pods -n infra | grep -c Running)
SLEEP_TIME=60
for i in {1..5}
do
        if [[ $cmd == 7 ]]
        then
                echo "All the infra objects are running"
                break
        else
                echo "Sleep for $SLEEP_TIME seconds"
                sleep $SLEEP_TIME

        fi
done

echo "Adding tracing and kibana pods to infra"
helm upgrade --install --create-namespace -n infra voltha-infra onf/voltha-infra --set voltha-tracing.enabled=true --set efk.enabled=true

echo "Waiting for the voltha infra pods to be up and running"
cmd=$(kubectl get pods -n infra | grep -c Running)
SLEEP_TIME=60
for i in {1..5}
do
        if [[ $cmd == 11 ]]
        then
                echo "All the infra objects are running"
                break
        else
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

