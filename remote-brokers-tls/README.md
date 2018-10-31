# remote brokers with TLS and mutual auth

Example configuration of connecting to a live/backup broker pair over TLS:

- 1 EAP server acting as live broker
- 1 EAP server acting as backup broker
- 1 EAP server running a client application
- Client authentication (mutual authentication) configured using certificates

First, create servers:

    export JBOSS_HOME=/path/to/your/jboss

    cp -a $JBOSS_HOME/standalone $JBOSS_HOME/broker1
    cp -a $JBOSS_HOME/standalone $JBOSS_HOME/broker2
    cp -a $JBOSS_HOME/standalone $JBOSS_HOME/client

Then copy the sample config files across:

    cp standalone-full-ha-broker1.xml $JBOSS_HOME/broker1/configuration/standalone-full-ha.xml
    cp standalone-full-ha-broker2.xml $JBOSS_HOME/broker2/configuration/standalone-full-ha.xml
    cp standalone-full-ha-client.xml $JBOSS_HOME/client/configuration/standalone-full-ha.xml

Create keystores, truststores and launch the servers:

    cd $JBOSS_HOME

    ./bin/add-user.sh -sc broker1/configuration -a -u 'jeffrey' -p 'jeffrey' -g 'guest'
    ./bin/add-user.sh -sc broker2/configuration -a -u 'jeffrey' -p 'jeffrey' -g 'guest'

    export JBOSS_HOME=/path/to/your/jboss

    keytool -genkeypair -alias broker1 \
        -keyalg RSA -keysize 1024 -validity 365 \
        -keystore $JBOSS_HOME/broker1.jceks \
        -dname "CN=broker1" \
        -storetype JCEKS \
        -keypass changeit -storepass changeit

    keytool -genkeypair -alias broker2 \
        -keyalg RSA -keysize 1024 -validity 365 \
        -keystore $JBOSS_HOME/broker2.jceks \
        -dname "CN=broker2" \
        -storetype JCEKS \
        -keypass changeit -storepass changeit
        
    keytool -genkeypair -alias client \
        -keyalg RSA -keysize 1024 -validity 365 \
        -keystore $JBOSS_HOME/client.jceks \
        -dname "CN=client" \
        -storetype JCEKS \
        -keypass changeit -storepass changeit

    keytool -export -alias broker1 \
        -keystore $JBOSS_HOME/broker1.jceks \
        -file $JBOSS_HOME/broker1.cer \
        -storetype JCEKS \
        -storepass changeit -keypass changeit

    keytool -export -alias broker2 \
        -keystore $JBOSS_HOME/broker2.jceks \
        -file $JBOSS_HOME/broker2.cer \
        -storetype JCEKS \
        -storepass changeit -keypass changeit
        
    keytool -export -alias client \
        -keystore $JBOSS_HOME/client.jceks \
        -file $JBOSS_HOME/client.cer \
        -storetype JCEKS \
        -storepass changeit -keypass changeit
        
    keytool -import -alias broker2 \
        -keystore $JBOSS_HOME/broker1.ts \
        -file $JBOSS_HOME/broker2.cer \
        -storetype JCEKS \
        -storepass changeit -noprompt
        
    keytool -import -alias client \
        -keystore $JBOSS_HOME/broker1.ts \
        -file $JBOSS_HOME/client.cer \
        -storetype JCEKS \
        -storepass changeit -noprompt

    keytool -import -alias broker1 \
        -keystore $JBOSS_HOME/broker2.ts \
        -file $JBOSS_HOME/broker1.cer \
        -storetype JCEKS \
        -storepass changeit -noprompt
        
    keytool -import -alias client \
        -keystore $JBOSS_HOME/broker2.ts \
        -file $JBOSS_HOME/client.cer \
        -storetype JCEKS \
        -storepass changeit -noprompt
        
    keytool -import -alias broker1 \
        -keystore $JBOSS_HOME/client.ts \
        -file $JBOSS_HOME/broker1.cer \
        -storetype JCEKS \
        -storepass changeit -noprompt

    keytool -import -alias broker2 \
        -keystore $JBOSS_HOME/client.ts \
        -file $JBOSS_HOME/broker2.cer \
        -storetype JCEKS \
        -storepass changeit -noprompt
        
    export JAVA_OPTS="-Djavax.net.debug=ssl,handshake"

    ./bin/standalone.sh -Djboss.node.name=broker1 \
        -Djboss.server.base.dir=./broker1 \
        -Dkeystore.path=./broker1.jceks \
        -Dkeystore.password=changeit \
        -Dkeystore.provider=JCEKS \
        -Dtruststore.path=./broker1.ts \
        -Dtruststore.password=changeit \
        -Dtruststore.provider=JCEKS \
        -c standalone-full-ha.xml

    ./bin/standalone.sh -Djboss.node.name=broker2 \
        -Djboss.socket.binding.port-offset=100 \
        -Djboss.server.base.dir=./broker2 \
        -Dkeystore.path=./broker2.jceks \
        -Dkeystore.password=changeit \
        -Dkeystore.provider=JCEKS \
        -Dtruststore.path=./broker2.ts \
        -Dtruststore.password=changeit \
        -Dtruststore.provider=JCEKS \
        -c standalone-full-ha.xml

    ./bin/standalone.sh -Djboss.node.name=client \
        -Djboss.socket.binding.port-offset=200 \
        -Djboss.server.base.dir=$JBOSS_HOME/client \
        -Dkeystore.path=$JBOSS_HOME/client.jceks \
        -Dkeystore.password=changeit \
        -Dkeystore.provider=JCEKS \
        -Dtruststore.path=$JBOSS_HOME/client.ts \
        -Dtruststore.password=changeit \
        -Dtruststore.provider=JCEKS \
        -c standalone-full-ha.xml

