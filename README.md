Apache Flink Docker Images
==========================

This repo contains Dockerfiles for building Docker images for Apache Flink, and are used to build
the "official" [`flink`](https://hub.docker.com/_/flink) images hosted on Docker Hub (reviewed and build by Docker), as well as the images published on [`apache/flink` DockerHub](https://hub.docker.com/r/apache/flink) (maintained by Flink committers).

These Dockerfiles are maintained by the Apache Flink community, but the Docker community is
responsible for building and hosting the images on Docker Hub.

[![Build Status](https://travis-ci.org/apache/flink-docker.svg?branch=master)](https://travis-ci.org/apache/flink-docker)


Flink Docker image lifecycle
----------------------------

* For more information about how changes in this repo are reflected on Docker Hub, see [the "An
  image's source changed in Git, now what?" FAQ entry](
  https://github.com/docker-library/faq#an-images-source-changed-in-git-now-what)
* For outstanding changes to the Apache Flink images on Docker Hub, see [PRs with the
  "library/flink" label on the `official-images` repository](
  https://github.com/docker-library/official-images/labels/library%2Fflink)
* For the "source of truth" for which Dockerfile and revision is reflected in the Apache Flink
  images on Docker Hub, see [the `library/flink` file in the `official-images` repository](
  https://github.com/docker-library/official-images/blob/master/library/flink).


Development workflow
----------------------------

The `master` branch of this repository serves as a pure publishing area for releases.

Development happens on the various `dev-X` branches.

Pull requests for a specific version should be opened against the respective `dev-<version>` branch.
Pull requests for all versions, or for the next major Flink release, should be opened against the `dev-master` branch.

### CI

The `dev-master` branch is tested against nightly Flink snapshots for the next major Flink version. This allows us to
develop features in tandem with Flink.

The `dev-1.x` branches are tested against the latest corresponding minor Flink release, to ensure any changes we make
are compatible with the currently used Flink version.

Workflow for new Flink releases
-------------------------------

### Notes for new Flink major (x.y.0) releases

There are additional steps required when a new Flink major version (x.y.0) is released.

* Since only the current and previous major versions of Flink are supported, the Dockerfiles for
  older versions must be removed when adding the new version to this repo
* The new images should be given the `latest` tag, so the `aliases` array in
  `generate-stackbrew-library.sh` must be updated


### Release workflow

When a new release of Flink is available, the Dockerfiles in the `master` branch should be updated and a new
manifest sent to the Docker Library [`official-images`](
https://github.com/docker-library/official-images) repo.

The Dockerfiles are generated on the respective `dev-<version>` branches, and copied over to the `master` branch for
publishing.

Updating the Dockerfiles involves the following steps:

1. Generate the Dockerfiles
    * Checkout the `dev-x.y`(minor release)/`dev-master`(major release) branch of the respective release, e.g., dev-1.9
    * Update `add-version.sh` with the GPG key ID of the key used to sign the new release
        * Commit this change with message `Add GPG key for x.y.z release` <sup>\[[example](
            https://github.com/apache/flink-docker/commit/94845f46c0f0f2de80d4a5ce309db49aff4655d0)]</sup>
    * (minor only) Update `testing/run_travis_tests.sh` to test against the new minor version.
    * Create a pull request against the `dev-x.y`/`dev-master` branch containing these commits.
    * Run `add-version.sh` with the appropriate arguments (`-r flink-major-version -f flink-full-version`)
        * e.g. `./add-version.sh -r 1.2 -f 1.2.1`
2. Update Dockerfiles on the the `master` branch
    * Remove any existing Dockerfiles from the same major version
        * e.g. `rm -r 1.2`, if the new Flink version is `1.2.1`
    * Copy the generated Dockerfiles from the `dev-x.y`/`dev-master` branch to `master`
    * Commit the changes with message `Update Dockerfiles for x.y.z release` <sup>\[[example](
      https://github.com/apache/flink-docker/commit/5920fd775ca1a8d03ee959d79bceeb5d6e8f35a1)]</sup>
    * Create a pull request against the `master` branch containing this commit.

Once the pull request has been merged, we can release the new docker images:

For **publishing to DockerHub: apache/flink** , you need to perform the following steps:

1. Make sure that you are authenticated with your Docker ID, and that your Docker ID has access to `apache/flink`. If not, request access by INFRA (see [also](https://issues.apache.org/jira/browse/INFRA-21276): `docker login -u <username>`.
2. Generate and upload the new images: `./publish-to-dockerhub.sh`.

For **publishing as an official image**, a new manifest should be generated and a pull request opened
on the Docker Library [`official-images`](https://github.com/docker-library/official-images) repo.

1. Run `./generate-stackbrew-library.sh` to output the new manifest (see note [below](
   #stackbrew-manifest) regarding usage of this script)
2. In a clone of the [`official-images`](https://github.com/docker-library/official-images) repo,
   overwrite the file `library/flink` with the new manifest
3. Commit this change with message `Update to Flink x.y.z` <sup>\[[example](
   https://github.com/docker-library/official-images/commit/396d6cfa03c4e6b41d3ba5b7c402d7b25f1db415
   )]</sup>

A pull request can then be opened on the [`official-images`](
https://github.com/docker-library/official-images) repo with the new manifest. <sup>\[[example](
https://github.com/docker-library/official-images/pull/7378)]</sup>

Once the pull request has been merged (often within 1 business day), the new images will be
available shortly thereafter.

For new major Flink releases, once the new image is available, the `dev-x.y` branch must be created:
1. Create the branch based on `dev-master`
2. update `testing/run_travis_tests.sh`:
    * replace usage of `./add-custom.sh` with `./add-version.sh -r x.y -f x.y.0`
    * replace references to `dev-master` with `dev-x.y`

### Release checklist

Checklist for the `dev` branch:
- [ ] The GPG key ID of the key used to sign the release has been added to `add-version.sh` and
      committed with the message `Add GPG key for x.y.z release`
- [ ] `./add-version.sh -r x.y -f x.y.z` has been run on the respective dev branch

Checklist for the `master` branch:
- [ ] _(new major releases only)_ any unsupported Flink major version Dockerfiles have been removed
      (only two `x.y/` directories should be present)
- [ ] _(new minor releases only)_ any existing generated files for the same major version have been
      removed
- [ ] The updated Dockerfiles have been committed with the message `Update Dockerfiles for x.y.z release`
- [ ] _(new major releases only)_ the `aliases` array in `generate-stackbrew-library.sh` has been
      updated with `[x.y]='latest'` and committed with the message `Update latest image tag to x.y`
- [ ] A pull request with the above changes has been opened on this repo and merged
- [ ] The new library manifest has been generated with `generate-stackbrew-library.sh` and a pull
      request opened on the `official-images` repo with commit message `Update to Flink x.y.z`


### Stackbrew Manifest

`generate-stackbrew-library.sh` is used to generate the library manifest file required for official
Docker Hub images.

When the Dockerfiles in this repo are updated, the output of this script should replace the contents
of `library/flink` in the Docker [official-images](https://github.com/docker-library/official-images
) repo via a pull request.

Note: Since this script requires the `bashbrew` binary and a compatible version of Bash, the script
`generate-stackbrew-library-docker.sh` can be used to invoke the script in a Docker container with
the necessary dependencies.

Example:

    ./generate-stackbrew-library-docker.sh > /path/to/official-images/library/flink


License
-------

Licensed under the Apache License, Version 2.0: https://www.apache.org/licenses/LICENSE-2.0

Apache Flink, Flink®, Apache®, the squirrel logo, and the Apache feather logo are either
registered trademarks or trademarks of The Apache Software Foundation.
