FROM openjdk:8-jre-alpine

ENV FLINK_VERSION=1.1.4 \
    HADOOP_VERSION=1 \
    SCALA_VERSION=2.10

ENV GPG_KEY 2BCCD5D49E8FEA6545E13DB6DE3E0F4C9D403309

RUN addgroup -S flink && adduser -S -G flink flink
RUN apk add --no-cache bash snappy

ENV FLINK_HOME /opt/flink
WORKDIR $FLINK_HOME
ENV PATH $FLINK_HOME/bin:$PATH

ENV FLINK_URL_FILE_PATH flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-hadoop${HADOOP_VERSION}-scala_${SCALA_VERSION}.tgz

# Not all mirrors have the .asc files
ENV FLINK_TGZ_URL=https://www.apache.org/dyn/closer.cgi?action=download&filename=${FLINK_URL_FILE_PATH} \
    FLINK_ASC_URL=https://www.apache.org/dist/${FLINK_URL_FILE_PATH}.asc

RUN set -ex; \
  apk add --no-cache --virtual .build-deps \
    ca-certificates \
    gnupg \
    openssl \
    tar \
  ; \
  \
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
  apk del .build-deps; \
  \
  chown -R flink:flink .;

COPY docker-entrypoint.sh /

USER flink
EXPOSE 6123 8081
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["--help"]
