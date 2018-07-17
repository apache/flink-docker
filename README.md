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


Stackbrew Manifest
------------------

`generate-stackbrew-library.sh` is used to generate the library file required for official Docker
Hub images.

When this repo is updated, the output of this script should be used to replaced the contents of
`library/flink` in the Docker [official-images](https://github.com/docker-library/official-images)
repo via a PR.

Note: running this script requires the `bashbrew` binary and a compatible version of Bash. The
Docker image `plucas/docker-flink-build` contains these dependencies and can be used to run this
script.

Example:

    docker run --rm \
        --volume /path/to/docker-flink:/build \
        plucas/docker-flink-build \
        /build/generate-stackbrew-library.sh \
    > /path/to/official-images/library/flink


License
-------

Licensed under the Apache License, Version 2.0: https://www.apache.org/licenses/LICENSE-2.0

Apache Flink, Flink®, Apache®, the squirrel logo, and the Apache feather logo are either
registered trademarks or trademarks of The Apache Software Foundation.
