#!/bin/bash

echo -n "Red Hat Registry Username: "
read RH_USERNAME

echo -n "Red Hat Registry Password: "
read -s RH_PASSWORD

oc create secret docker-registry rh-secret \ 
    --docker-username=${RH_USERNAME} \ 
    --docker-password=${RH_PASSWORD} \ 
    --docker-server=registry.redhat.io

oc secrets link builder rh-secret

oc secrets link default rh-secret --for=pull

