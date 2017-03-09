# docker-flink
Docker packaging for Apache Flink

Use `add-version.sh` to rebuild the Dockerfiles and all variants for a
particular Flink release release. Before running this, you must first delete
the existing release directory.

    usage: ./add-version.sh -r flink-release -f flink-version

TODO: to conform with other similar setups, this likely needs to become
`update.sh` and be taught how to derive the latest version (e.g. 1.2.0) from a
given release (e.g. 1.2) and assemble a `.travis.yml` file dynamically. Two
examples are
[httpd](https://github.com/docker-library/httpd/blob/master/update.sh) and
[cassandra](https://github.com/docker-library/cassandra/blob/master/update.sh).

TODO: we may want to teach `docker-entrypoint.sh` to drop privs to the flink
user so `docker run flink bash` gives a root shell into the container.
