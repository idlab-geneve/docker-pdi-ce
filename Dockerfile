#
# This docker image is just for development and testing purpose - please do NOT use on production
#

# Pull Base Image
FROM zhicwu/java:8

# Set Maintainer Details
MAINTAINER Zhichun Wu <zhicwu@gmail.com>

# Set Environment Variables
ENV PDI_VERSION=6.1 PDI_BUILD=6.1.0.1-196 PDI_PATCH=6.1.0.1-SNAPSHOT PDI_USER=pentaho \
	MYSQL_DRIVER_VERSION=5.1.40 JTDS_VERSION=1.3.1 CASSANDRA_DRIVER_VERSION=0.6.1 \
	JNA_VERSION=4.2.2 OSHI_VERSION=3.2 KETTLE_HOME=/data-integration

# Install Required Packages and Add User
RUN apt-get update \
	&& apt-get install -y libjna-java \
	&& rm -rf /var/lib/apt/lists/* \
	&& useradd -md $KETTLE_HOME -s /bin/bash $PDI_USER

# Download Pentaho Data Integration Community Edition and Unpack
RUN wget --progress=dot:giga http://downloads.sourceforge.net/project/pentaho/Data%20Integration/${PDI_VERSION}/pdi-ce-${PDI_BUILD}.zip \
	&& unzip -q *.zip \
	&& rm -f *.zip

# Add Entry Point and Templates
COPY docker-entrypoint.sh $KETTLE_HOME/docker-entrypoint.sh

# Switch Directory
WORKDIR $KETTLE_HOME

# Download and Apply Patches
RUN wget --progress=dot:giga https://github.com/zhicwu/pdi-cluster/releases/download/${PDI_PATCH}/pentaho-kettle-${PDI_PATCH}.jar \
	&& unzip -q pentaho-kettle*.jar -d classes \
	&& rm -f pentaho-kettle*.jar \
	&& wget https://maven.java.net/content/repositories/releases/net/java/dev/jna/jna/$JNA_VERSION/jna-$JNA_VERSION.jar \
		https://maven.java.net/content/repositories/releases/net/java/dev/jna/jna-platform/$JNA_VERSION/jna-platform-$JNA_VERSION.jar \
		http://central.maven.org/maven2/com/github/dblock/oshi-core/$OSHI_VERSION/oshi-core-$OSHI_VERSION.jar \
	&& mv *.jar lib/.

# Update JDBC Drivers
RUN wget --progress=dot:giga http://central.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}.jar \
		http://central.maven.org/maven2/net/sourceforge/jtds/jtds/${JTDS_VERSION}/jtds-${JTDS_VERSION}.jar \
		http://central.maven.org/maven2/com/github/zhicwu/cassandra-jdbc-driver/${CASSANDRA_DRIVER_VERSION}/cassandra-jdbc-driver-${CASSANDRA_DRIVER_VERSION}-shaded.jar \
	&& rm -f lib/mysql*.jar lib/jtds*.jar \
	&& mv *.jar lib/.

# Install Plugins
# TODO:
# 1) https://github.com/graphiq-data/pdi-streamschemamerge-plugin
# 2) https://github.com/graphiq-data/pdi-fastjsoninput-plugin

# Configure PDI
# plugins/kettle5-log4j-plugin/log4j.xml
RUN rm -rf system/osgi/log4j.xml classes/log4j.xml pwd/* simple-jndi/* system/karaf/data/tmp \
	&& chmod +x *.sh \
	&& sed -i -e 's|\(.*if \[ \$OS = "linux" \]; then\)|if \[ \$OS = "n/a" \]; then|' spoon.sh \
	&& sed -i 's/^\(respectStartLvlDuringFeatureStartup=\).*/\1true/' system/karaf/etc/org.apache.karaf.features.cfg \
	&& sed -i 's/^\(featuresBootAsynchronous=\).*/\1false/' system/karaf/etc/org.apache.karaf.features.cfg

VOLUME ["$KETTLE_HOME/logs", "$KETTLE_HOME/system/karaf/caches", "$KETTLE_HOME/system/karaf/data", "/tmp"]

ENTRYPOINT ["/usr/local/bin/tini", "--", "./docker-entrypoint.sh"]

#  8080 - Carte Web Service
#  8802 - Karaf SSHD
#  9052 - OSGi Service
#EXPOSE 8080 8802 9052

#CMD ["slave"]
