# docker
#docker-install:
#	./scripts/docker/install.sh
#
#docker-start:
#	./scripts/docker/start.sh
#
#docker-rebuild:
#	./scripts/docker/start.sh
#
#docker-stop:
#	./scripts/docker/stop.sh
#
#docker-remove:
#	./scripts/docker/remove.sh


.PHONY: docker-%
docker-%:
	./scripts/docker/$*.sh