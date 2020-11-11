# eap73-ocp-property-expansion

Testing whether some keystore password property can be expanded on startup.

## Set up EAP as normal - test regular SSL function via environment variables

Set up Red Hat registry credentials and import the EAP 7.3 image:

    ./registry-auth.sh
    oc apply -f eap73-image-stream.json

Generate a self-signed cert for the app, pop it into a Java keystore, and put that into a secret:

    ./generate-certs.sh
    oc create secret generic eap7-app-secret --from-file=keystore.jks=server.ks

Process the https-s2i template, to create an EAP instance serving HTTPS using the self-signed cert:

    oc process -f eap73-https-s2i.json \ 
        -p APPLICATION_NAME=eap-ssl \ 
        -p SOURCE_REPOSITORY_URL=https://github.com/monodot/eap-demos.git \ 
        -p SOURCE_REPOSITORY_REF=master \ 
        -p CONTEXT_DIR=helloworld-props \ 
        -p HTTPS_PASSWORD=changeit \ 
        -p IMAGE_STREAM_NAMESPACE=$(oc project -q) | oc apply -f -

With `openssl`, verify that the server is presenting the correct certificate:

    REMOTE_HOST=secure-eap-ssl-toms-project.apps.shared-na4.na4.openshift.opentlc.com
    echo | openssl s_client -servername ${REMOTE_HOST} -connect ${REMOTE_HOST}:443 2>/dev/null | openssl x509 -noout -text

This should show something like _"L = Gimmerton"_:

    Certificate:
        Data:
            Version: 3 (0x2)
            Serial Number: 1473871369 (0x57d97e09)
            Signature Algorithm: sha256WithRSAEncryption
            Issuer: L = Gimmerton, CN = server

## Use a custom standalone-openshift.xml with keystore properties from env vars

Build a new custom base image, with a custom standalone-openshift.xml:

    oc new-build jboss-eap73-openshift:7.3~https://github.com/monodot/eap-demos.git \ 
        --name my-custom-eap \ 
        --context-dir eap73-ocp-property-expansion/custom-s2i \ 
        --allow-missing-images 

Patch the build above to use this new custom image as a base, instead of the regular EAP imagestream:

    oc patch bc/eap-ssl-build-artifacts --type=json -p='[ {"op": "replace", "path": "/spec/strategy/sourceStrategy/from/name", "value": "my-custom-eap:latest" }]'

Now update the environment variables on the Deployment Config, unsetting the old vars, and setting our new custom keystore path and password env vars:

    oc set env dc/eap-ssl HTTPS_KEYSTORE_DIR="" \ 
        HTTPS_KEYSTORE="" \ 
        FOO_KEYSTORE_PATH="/etc/eap-secret-volume/keystore.jks" \ 
        FOO_KEYSTORE_PASSWORD="changeit"

Now the app should use the cert from the keystore.

This could optionally be extended to source the environment variable values from a ConfigMap or Secret, instead of providing the values explicitly here.

**Note:** If you use custom environment variables in this way, ensure they don't conflict with the ones expected by EAP out of the box. For example, you shouldn't reuse the names `HTTPS_PASSWORD` and `HTTPS_KEYSTORE_DIR` because these are both used internally by the EAP startup script, to customise the server config.
