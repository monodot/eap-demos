# eap73-ocp-properties

Create a ConfigMap:

    oc create configmap app-config --from-file=foo.properties=foo.properties

Patch a DeploymentConfig to add the `app-config` CM as a volume:

    oc patch dc/eap-app --type=json -p='[ {"op": "add", "path": "/spec/template/spec/volumes", "value": []}, {"op": "add", "path": "/spec/template/spec/volumes/-", "value": { "name": "config-volume", "configMap": { "name": "app-config" }}}, {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts", "value": []}, {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": { "name": "config-volume", "mountPath": "/etc/config"}} ]'


