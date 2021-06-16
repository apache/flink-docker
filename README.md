# flink-docker / dev-master

## Building a custom docker image

1. Compress Flink in `flink-dist/target/flink-1.11-SNAPSHOT-bin`: `tar czf flink-1.11.tgz flink-1.11-SNAPSHOT`
2. Start web server ``docker run -it -p 9999:9999 -v `pwd`:/data python:3.7.7-slim-buster python -m http.server 9999``
3. Generate `Dockerfile` `./add-custom.sh -u http://localhost:9999/data/flink-1.11.tgz -n flink-1.11`
	(If you are on a Mac or Windows, use `host.docker.internal` instead of `localhost`)
	* If you want to build the docker image inside Minikube, then you have to specify the resolved `host.minikube.internal` which you can look up via `minikube ssh "cat /etc/hosts"`.
4. Generate docker image (in `flink-docker/dev/flink-1.11-debian`): `docker build -t flink:1.11-SN .`
5. Run custom Flink docker image: `docker run -it flink:1.11-SN jobmanager`

