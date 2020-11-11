# eap73-ocp-property-expansion

Testing whether some keystore password property can be expanded on startup.

Set up Red Hat registry credentials and import the EAP 7.3 image:

    ./registry-auth.sh
    oc apply -f eap73-image-stream.json

Customise the base image by providing a standalone-openshift.xml

    oc new-build . --image-stream=jboss-eap73-openshift

Generate a self-signed cert for the app, pop it in a Java keystore, and put it in a secret:

    ./generate-certs.sh
    oc create secret generic eap7-app-secret --from-file=keystore.jks=server.ks

Process the https-s2i template:

    oc process -f eap73-https-s2i.json -p APPLICATION_NAME=eap-ssl -p SOURCE_REPOSITORY_URL=https://github.com/monodot/eap-demos.git -p SOURCE_REPOSITORY_REF=master -p CONTEXT_DIR=helloworld-props -p HTTPS_PASSWORD=changeit -p IMAGE_STREAM_NAMESPACE=$(oc project -q) 

Then verify that the server is presenting the correct certificate:

    REMOTE_HOST=secure-eap-ssl-toms-project.apps.shared-na4.na4.openshift.opentlc.com
    echo | openssl s_client -servername ${REMOTE_HOST} -connect ${REMOTE_HOST}:443 2>/dev/null | openssl x509 -noout -text

This should show something like:

    Certificate:
        Data:
            Version: 3 (0x2)
            Serial Number: 1473871369 (0x57d97e09)
            Signature Algorithm: sha256WithRSAEncryption
            Issuer: L = Gimmerton, CN = server

