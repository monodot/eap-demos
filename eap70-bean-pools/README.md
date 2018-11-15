# Bean pool demo

Demonstrating bean instance pools in JBoss EAP.

First, create a new server config directory:

    export JBOSS_HOME=/path/to/your/jboss

    cp -a $JBOSS_HOME/standalone $JBOSS_HOME/beanpools

Then copy the sample config files across:

    cp standalone-full-beanpools.xml $JBOSS_HOME/beanpools/configuration/standalone-full-beanpools.xml
    
Create user and launch the server:

    cd $JBOSS_HOME

    ./bin/add-user.sh -sc beanpools/configuration -u 'admin' -p 'admin'
    ./bin/add-user.sh -sc beanpools/configuration -a -u 'jeffrey' -p 'jeffrey' -g 'guest'

    ./bin/standalone.sh -Djboss.node.name=beanpools \
        -Djboss.server.base.dir=./beanpools \
        -c standalone-full-beanpools.xml

Deploy sample MDB application and run JConsole:

    cd ../eap70-helloworld-mdb-consumer

    mvn clean wildfly:deploy
    
    jconsole &

The consumer will fail to deploy if JMS destinations have not already been already created:

    jms-queue add --queue-address=HelloWorldMDBQueue --entries=[java:/queue/HELLOWORLDMDBQueue]
    
    jms-topic add --topic-address=HelloWorldMDBTopic --entries=[java:/topic/HELLOWORLDMDBTopic]

Once deployed, observe the following:

- The consumer count on the runtime queue `HelloWorldMDBQueue` is the same as the `maxSession` config property on the `HelloWorldQueueMDB` class.
- Navigate to jboss.as --> helloworld-mdb-consumer --> ejb3 --> HelloWorldQueueMDB --> Attributes
  - _poolName_ = `mdb-strict-max-pool`
  - _poolMaxSize_ = 16 (a number that is automatically derived from the CPU count on my computer, yours may vary)
  - _poolCurrentSize_ = 0 (because it's not consuming messages yet)

Deploy the test message producer:

    cd ../eap70-helloworld-mdb-producer

    mvn clean wildfly:deploy

Now push some messages into ActiveMQ:

    while true; do curl http://localhost:8080/helloworld-mdb-producer/HelloWorldMDBServletClient\?count=500 ; sleep 2; done

In JConsole, observe the stats on HelloWorldQueueMDB:

- _poolAvailableCount_ rises to 16 (the max set by `mdb-strict-max-pool`)
- _poolCurrentSize_ will rise to only a max of 8 (the same value which is set in _maxSession_)
- _poolMaxSize_ stays at 16 (the max set by `mdb-strict-max-pool`)
- _consumerCount_ on the queue itself stays the same as the `maxSession` parameter.

Some example processing times:

- 10,500 messages consumed in approx 20 seconds (with `maxSession` = 2)
- 10,000 messages consumed in approx 5 seconds (with max pool size and maxSession = 200)

Changing the strict max pool size from derived to an explicit value:

    :undefine-attribute(name=derive-size)
    :write-attribute(name=max-pool-size, value=200)
    
