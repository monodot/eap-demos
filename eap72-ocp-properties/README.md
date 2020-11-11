# eap73-ocp-properties

Showing how you can use the `JBOSS_MESSAGING_ARGS` environment variable to pass extra config to EAP.

First deploy an application using the standard EAP 7.3 template on OpenShift. e.g.:

    oc process -f eap72-basic-s2i.yml -p SOURCE_REPOSITORY_URL=https://github.com/monodot/eap-demos.git -p SOURCE_REPOSITORY_REF=master -p CONTEXT_DIR=helloworld-props | oc apply -f -

Let the build complete.

Create a ConfigMap from the properties file in this dir:

    oc create configmap app-config --from-file=foo.properties=foo.properties

Patch a DeploymentConfig to add the `app-config` CM as a volume:

    oc patch dc/eap-app --type=json -p='[ {"op": "add", "path": "/spec/template/spec/volumes", "value": []}, {"op": "add", "path": "/spec/template/spec/volumes/-", "value": { "name": "config-volume", "configMap": { "name": "app-config" }}}, {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts", "value": []}, {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts/-", "value": { "name": "config-volume", "mountPath": "/etc/config"}} ]'

And set up the `JBOSS_MESSAGING_ARGS` env var:

    oc patch dc/eap-app --type=json -p='[ {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": { "name": "JBOSS_MESSAGING_ARGS", "value": "--properties=/etc/config/foo.properties"}} ]'

Then you should see the property written out in the response:

    $ curl https://eap-app-toms-project.apps.shared-na4.na4.openshift.opentlc.com/HelloWorld | grep 'foo.greeting'
    foo.greeting = Hello, world!

## Patching an existing build

If you've already deployed EAP with the default quickstart app, you can patch your build to use the helloworld demo in this repo:

    oc patch bc/eap-app --type=json -p='[ {"op": "replace", "path": "/spec/source", "value": { "type": "Git", "git":{"uri":"https://github.com/monodot/eap-demos.git", "ref":"master"}, "contextDir": "helloworld-props"}}]'

Theh, start the build:

    oc start-build eap-app --follow
