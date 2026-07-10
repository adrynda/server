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

.PHONY: rebuild
rebuild: projects-down-dev docker-down docker-build projects-build-dev

# Aider na całym server/ (bez gita, tylko ręczne /add) - configi infry + wszystkie projekty
.PHONY: aider
aider:
	cd _infrastructure && docker compose run --rm aider

# Aider z repo-mapą, ograniczony do jednego projektu (jego własne repo gita)
# użycie: make aider-project-symfony.messenger
.PHONY: aider-project-%
aider-project-%:
	cd _infrastructure && docker compose run --rm --workdir /workspace/projects/$* aider-project

#.PHONY: projects-%
#projects-%:
#	./scripts/projects/$*.sh

#docker stop $(docker ps -q)
