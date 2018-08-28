SECRET:=$(shell cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

setup: init-env pull
	docker network create proxy || true
	docker volume create --name=pmcconfig || true
	docker volume create --name=db_data || true
	make logs

init-env: check-urls-env
ifeq ($(wildcard etc/db.env),)
	cp etc/traefik.toml.sample etc/traefik.toml
	cp etc/db.sample.env etc/db.env
	sed -i s/password/$(SECRET)/g etc/db.env
	@echo "Generated etc/db.env"
else
	@echo "etc/db.env already exists"
endif

check-urls-env:
ifeq ($(wildcard etc/urls.env),)
	@echo "etc/urls.env file is missing"
	@exit 1
else
include etc/urls.env
export
endif

check-cloud-env:
ifeq ($(wildcard etc/cloud.env),)
	@echo "etc/cloud.env file is missing"
	@exit 1
else
include etc/cloud.env
export
endif

ps:
	# A lightly formatted version of docker ps
	docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'

pull:
	docker-compose pull

up: check-urls-env
	docker-compose up -d

down:
	docker-compose down

logs: up
	docker-compose logs --tail 10 -f

##################################
# Deployment to Application Cloud

login: check-cloud-env
	docker login -u ${DOCKER_HUB_USERNAME} -p ${DOCKER_HUB_PASSWORD}
	cf login -a ${APPCLOUD_URL} -u ${APPCLOUD_USER}

build:
	# nginx
	cd nginx && docker build . -t ${DOCKER_HUB_REPONAME}/nginx
	# traefik
	cd traefik && docker build --build-arg ADMIN_PORT=${TRAEFIK_ADMIN_PORT} . -t ${DOCKER_HUB_REPONAME}/traefik

push-hub: check-cloud-env
	docker push ${DOCKER_HUB_REPONAME}/nginx
	docker push ${DOCKER_HUB_REPONAME}/traefik

push-cloud: check-cloud-env
	CF_DOCKER_PASSWORD=${DOCKER_HUB_PASSWORD} cf push ${NGINX_APPNAME} --docker-image ${DOCKER_HUB_REPONAME}/nginx  --docker-username ${DOCKER_HUB_USERNAME}
	CF_DOCKER_PASSWORD=${DOCKER_HUB_PASSWORD} cf push ${TRAEFIK_APPNAME} --docker-image ${DOCKER_HUB_REPONAME}/traefik  --docker-username ${DOCKER_HUB_USERNAME}
