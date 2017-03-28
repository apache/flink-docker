docker-flink
============

Docker packaging for Apache Flink

Use `add-version.sh` to rebuild the Dockerfiles and all variants for a
particular Flink release release. Before running this, you must first delete
the existing release directory.

    usage: ./add-version.sh -r flink-release -f flink-version

Example
-------

    $ rm -r 1.2
    $ ./add-version.sh -r 1.2 -f 1.2.1
