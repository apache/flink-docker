###############################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

FROM openjdk:8-jre

# Configure Flink version
ENV FLINK_VERSION=1.1.4 \
    HADOOP_VERSION=2 \
    SCALA_VERSION=2.11 \
    GPG_KEY=2BCCD5D49E8FEA6545E13DB6DE3E0F4C9D403309

# Prepare environment
ENV FLINK_USER=flink \
    FLINK_UID=9999 \
    FLINK_HOME=/opt/flink
ENV PATH=$FLINK_HOME/bin:$PATH
RUN groupadd --system --gid=$FLINK_UID $FLINK_USER && \
    useradd --system --uid=$FLINK_UID --gid $FLINK_USER $FLINK_USER
WORKDIR $FLINK_HOME

# Install build dependencies and flink
ENV FLINK_URL_FILE_PATH flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala_${SCALA_VERSION}.tgz
# Not all mirrors have the .asc files
ENV FLINK_TGZ_URL=https://www.apache.org/dyn/closer.cgi?action=download&filename=${FLINK_URL_FILE_PATH} \
    FLINK_ASC_URL=https://www.apache.org/dist/${FLINK_URL_FILE_PATH}.asc

RUN apt-get update && \
  apt-get -y install libsnappy1 && \
  rm -rf /var/lib/apt/lists/*
RUN set -ex; \
  wget -O flink.tgz "$FLINK_TGZ_URL"; \
  wget -O flink.tgz.asc "$FLINK_ASC_URL"; \
  \
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY"; \
  gpg --batch --verify flink.tgz.asc flink.tgz; \
  rm -r "$GNUPGHOME" flink.tgz.asc; \
  \
  tar -xf flink.tgz --strip-components=1; \
  rm flink.tgz; \
  \
  chown -R $FLINK_USER:$FLINK_USER .;

# Configure container
USER flink
ADD docker-entrypoint.sh $FLINK_HOME/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 6123 8081
CMD ["help"]
