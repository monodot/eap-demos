# SPNEGO / SSO with Kerberos demo

This is a demo of setting up Single Sign-on for a Java application using Kerberos (via the SPNEGO support in JBoss EAP/Wildfly).

This demo is basically a walkthrough of the [spnego-demo application by Josef Cacek][1].

This example is designed for **EAP 7.0**, which uses the legacy security subsystem.

## Setup

This demo is intended to run on a RHEL host. 

The included _Vagrantfile_ can be used to launch a RHEL guest machine (using the image from <https://app.vagrantup.com/generic/boxes/rhel7>). Port forwarding is configured, to forward the guest port 8080 forwarded to 18080 on the host.

To bring up the guest machine (this should also download the RHEL Vagrant box):

```
$ vagrant up
$ vagrant ssh
```

## Method

Inside the RHEL machine, firstly attach to subscription manager:

```
$ sudo subscription-manager register
$ sudo subscription-manager attach
$ sudo subscription-manager repos --list
$ sudo yum install -y wget unzip java-1.8.0-openjdk-devel krb5-workstation maven git firefox
$ sudo yum-config-manager --enable rhel-server-rhscl-7-rpms
$ sudo yum install rh-maven35
```

Add a firewall rule allowing inbound traffic on 8080:

```
$ sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
$ sudo firewall-cmd --reload
```

Create the `jboss` user:

```
$ sudo mkdir -p /opt/rh/jboss
$ sudo mkdir /home/jboss
$ sudo groupadd -f -g 185 -r jboss
$ sudo useradd -r -u 185 -d /home/jboss -g jboss -c "JBoss" jboss
$ sudo chown jboss:jboss /home/jboss
$ sudo chown jboss:jboss /opt/rh/jboss
```

In another window, start a sample Kerberos server, implemented using the ApacheDS library. This will:

- start the server on `localhost:6088`
- create a Kerberos client config file `/tmp/krb5.conf`
- copy the client config file to the default system location in `/etc`
- create a keytab file for the HTTP user, `http.keytab`

```
$ sudo su - jboss
$ git clone https://github.com/kwart/kerberos-using-apacheds.git
$ git clone https://github.com/kwart/spnego-demo.git
$ export SPNEGO_TEST_DIR=/tmp/spnego-demo-testdir
$ mkdir $SPNEGO_TEST_DIR
$ scl enable rh-maven35 bash
$ cd ~/kerberos-using-apacheds
$ mvn clean package
$ cp test.ldif target/kerberos-using-apacheds.jar $SPNEGO_TEST_DIR
$ cd $SPNEGO_TEST_DIR
$ java -jar kerberos-using-apacheds.jar test.ldif &
$ sudo mv /etc/krb5.conf /etc/krb5.conf.old
$ sudo cp $SPNEGO_TEST_DIR/krb5.conf /etc/krb5.conf

$ java -classpath kerberos-using-apacheds.jar \
    org.jboss.test.kerberos.CreateKeytab \
    HTTP/localhost@JBOSS.ORG \
    httppwd \
    http.keytab
    
# Keep this window open.
```

Keep this window open so that the ApacheDS directory server continues to run.

In the other terminal window, download the EAP binary from wherever it's located, extract and launch. The following assumes the binary is stored in an S3 bucket. **NB: don't do this on a production server as it will leave your AWS credentials in the command history.**

```
$ curl -O https://bootstrap.pypa.io/get-pip.py
$ sudo python get-pip.py

$ sudo su - jboss

jboss@$ pip install awscli --upgrade --user
jboss@$ BUCKET_NAME=xxxx AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=yyyy \ 
    ~/.local/bin/aws s3 cp s3://${BUCKET_NAME}/dists/jboss-eap-7.0.0.zip .
jboss@$ cd /opt/rh/jboss
jboss@$ unzip jboss-eap-7.0.0.zip
jboss@$ cd jboss-eap-7.0.0/
jboss@$ ./bin/add-user.sh -u 'admin' -p 'admin'
jboss@$ export SPNEGO_TEST_DIR=/tmp/spnego-demo-testdir
jboss@$ nohup ./bin/standalone.sh > jboss.out &
```

Now configure SPNEGO in Wildfly using the JBoss CLI:

```
jboss@$ cat << EOT > cli-commands.txt
embed-server
/subsystem=security/security-domain=host:add(cache-type=default)
/subsystem=security/security-domain=host/authentication=classic:add(login-modules=[{"code"=>"Kerberos", "flag"=>"required", "module-options"=>[ ("debug"=>"true"),("storeKey"=>"true"),("refreshKrb5Config"=>"true"),("useKeyTab"=>"true"),("doNotPrompt"=>"true"),("keyTab"=>"$SPNEGO_TEST_DIR/http.keytab"),("principal"=>"HTTP/localhost@JBOSS.ORG")]}]) {allow-resource-service-restart=true}

/subsystem=security/security-domain=SPNEGO:add(cache-type=default)
/subsystem=security/security-domain=SPNEGO/authentication=classic:add(login-modules=[{"code"=>"SPNEGO", "flag"=>"required", "module-options"=>[("serverSecurityDomain"=>"host")]}]) {allow-resource-service-restart=true}
/subsystem=security/security-domain=SPNEGO/mapping=classic:add(mapping-modules=[{"code"=>"SimpleRoles", "type"=>"role", "module-options"=>[("jduke@JBOSS.ORG"=>"Admin"),("hnelson@JBOSS.ORG"=>"User")]}]) {allow-resource-service-restart=true}

/system-property=java.security.krb5.conf:add(value="$SPNEGO_TEST_DIR/krb5.conf")
/system-property=java.security.krb5.debug:add(value=true)
/system-property=jboss.security.disable.secdomain.option:add(value=true)
EOT

jboss@$ ./bin/jboss-cli.sh --file=cli-commands.txt
jboss@$ ./bin/jboss-cli.sh --commands=connect,reload
```

Deploy the sample application:

```
jboss@$ cd ~/spnego-demo
jboss@$ scl enable rh-maven35 bash
jboss@$ mvn clean org.wildfly.plugins:wildfly-maven-plugin:deploy
```

As the `jboss` user, fetch a Kerberos ticket using `kutil`, the utility to obtain and cache a Kerberos _ticket-granting ticket_:

```
$ kinit hnelson@JBOSS.ORG << EOT
secret
EOT
```

You can confirm the ticket was granted by running `klist`:

```
$ klist
Ticket cache: FILE:/tmp/krb5cc_185
Default principal: hnelson@JBOSS.ORG

Valid starting       Expires              Service principal
11/19/2018 10:40:40  11/20/2018 10:40:40  krbtgt/JBOSS.ORG@JBOSS.ORG
```

Now access the demo web application - this must be done from the machine itself (so that the Kerberos token is picked up):

1.  Start Firefox (e.g. `export DISPLAY=127.0.0.1:10.0; firefox &`)
2.  Go to http://localhost:8080/spnego-demo
3.  Browse to demo the SSO functionality.

To bring up the demo at any time, once it's already been configured:

```
$ vagrant up
$ vagrant ssh

$ sudo su - jboss
$ export SPNEGO_TEST_DIR=/tmp/spnego-demo-testdir
$ cd $SPNEGO_TEST_DIR
$ nohup java -jar kerberos-using-apacheds.jar test.ldif > output.log &
$ cd /opt/rh/jboss/jboss-eap-7.0
$ nohup ./bin/standalone.sh -b 0.0.0.0 > jboss.out &
```


[1]: https://github.com/kwart/spnego-demo

