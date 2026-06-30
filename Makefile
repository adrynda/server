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

.PHONY: projects-setup-%
projects-setup-%:
	./scripts/projects/setup.sh $*

.PHONY: projects-build-%
projects-build-%:
	./scripts/projects/build.sh $*

.PHONY: projects-up-%
projects-up-%:
	./scripts/projects/up.sh $*

.PHONY: projects-down-%
projects-down-%:
	./scripts/projects/down.sh $*

#.PHONY: projects-%
#projects-%:
#	./scripts/projects/$*.sh
