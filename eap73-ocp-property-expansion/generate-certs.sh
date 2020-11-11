#!/bin/sh

SERVER_DN="CN=server,L=Gimmerton"
CLIENT_DN="CN=client,L=Gimmerton"

keytool -genkey -alias server -validity 3650 -keypass changeit -keyalg RSA -keystore server.ks -dname "${SERVER_DN}" -storepass changeit -storetype pkcs12
keytool -genkey -alias client -validity 3650 -keypass changeit -keyalg RSA -keystore client.ks -dname "${CLIENT_DN}" -storepass changeit -storetype pkcs12

keytool -export -alias server -keystore server.ks -file server_cert -deststoretype pkcs12 -storepass changeit
keytool -import -alias server -keystore client.ts -file server_cert -deststoretype pkcs12 -storepass changeit -noprompt

keytool -export -alias client -keystore client.ks -file client_cert -storepass changeit
keytool -import -alias client -keystore server.ts -file client_cert -storepass changeit -noprompt
