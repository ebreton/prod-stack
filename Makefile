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
