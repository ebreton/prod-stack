README
==

This repository will provide you with a (modular) basic dockerized web stack :

* `make proxy`: a reverse proxy based on [traefik v2.0](https://traefik.io)
* `make db`: proxy + a [mariaDB](https://mariadb.org) (along with a [phpmyadmin](https://www.phpmyadmin.net))
* `make cache`: proxy + a [memcached](https://memcached.org) server (along with a [phpmemcachedadmin](https://github.com/elijaa/phpmemcachedadmin))
* `make all`: the 3 components above

Table of Content
--

<!-- TOC -->autoauto- [Configuration](#configuration)auto    - [Pre-requisites](#pre-requisites)auto    - [Setup](#setup)auto    - [Sanity checks](#sanity-checks)auto    - [Router check](#router-check)auto- [Components](#components)auto    - [Web service](#web-service)auto        - [in common words...](#in-common-words)auto        - [step by step](#step-by-step)auto        - [Basic Authentication](#basic-authentication)autoauto<!-- /TOC -->

## Configuration

### Pre-requisites

* make
* [docker](https://www.docker.com/community-edition)
* [docker-compose](https://docs.docker.com/compose/install/)

### Setup

A `.env` file will be created when you will call your first command. Make sure to look at in an change the default values according to your needs, in particular:

* your own email used for let's encrypt. This will allow `traefik` to register certificates for you on Let's Encrypt.
* your own user for Basic Authentication (used for traefik `dashboard`). The default is set to _test/test_. `htpasswd` will help you in this, check [traefic doc](https://docs.traefik.io/middlewares/basicauth/) for more details

Here are all the default values:

    # TRAEFIK
    TRAEFIK_DOMAIN=localhost
    BASIC_AUTH='test:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/'
    LETSENCRYPT_EMAIL=admin@domain.com
    CLOUDFLARE_EMAIL=admin@domain.com
    CLOUDFLARE_API_KEY=api-key

    # MariaDB
    DEFAULT_PROTOCOL=http
    PHPMYADMIN_DOMAIN=localhost
    PHPMYADMIN_PATH=phpmyadmin

    # Memcache
    PHPMEMCACHEDADMIN_DOMAIN=phpmemcachedadmin
    PHPMEMCACHEDADMIN_PATH=phpmemcachedadmin

### Let's Encrypt and OVH

Check the full tutorial at https://medium.com/nephely/configure-traefik-for-the-dns-01-challenge-with-ovh-as-dns-provider-c737670c0434

It will make you create an application key for your account (using wildchar * in example below, which will allow traefik to manage all your OVH domains)

    curl -XPOST -H "X-Ovh-Application: <application_key>" -H "Content-type: application/json" https://eu.api.ovh.com/1.0/auth/credential -d '{ "accessRules":[{"method":"POST","path":"/domain/zone/*/record"},{"method":"POST","path":"/domain/zone/*/refresh"},{"method":"DELETE","path":"/domain/zone/*/record/*"}],"redirection": "https://www.ovh.com/manager"}'

For the record, the API console is located at https://api.ovh.com/console

### Sanity checks

You will be able to check that everything went ok either through the logs (`make logs`), or by simply running `make` (which actually runs `make ps`)

    $ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}} ago'
    NAMES               IMAGE                           STATUS ago
    traefik             traefik:latest                  Up 14 minutes ago
    ...

You should also be able to:

* connect to traefik dashboard on <http://localhost:8080/dashboard/> (provided you set up Basic Authentication as described in the [Setup](#setup) section above)
* connect to phpmyadmin on <http://localhost/phpmyadmin/>
* connect to phpmemcachedamdin on <http://localhost:8081/phpmemcachedadmin/>

The URLs above are defined thanks to variable environement with the following default values:

    DEFAULT_PROTOCOL=http
    PHPMYADMIN_DOMAIN=localhost
    PHPMYADMIN_PATH=phpmyadmin
    PHPMEMCACHEDADMIN_DOMAIN=phpmemcachedadmin

### Router check

In order to check that the routing is correctly managed by  `traefik`, you can launch a simple [hello-world container](https://github.com/docker/dockercloud-hello-world/blob/master/README.md).

First modify your `/etc/hosts` by adding the following line

    127.0.0.1   hello.localhost

The following command will launch and route this on <https://hello.localhost>. It makes use of labels as described with more details in the following section

    docker run -d --name hello-world --rm \
        --network=traefik-public \
        --label "traefik.enable=true" \
        --label "traefik.docker.network=traefik-public" \
        --label "traefik.http.routers.hello.rule=Host(\`hello.localhost\`)" \
        --label "traefik.http.routers.hello.entrypoints=websecure" \
        dockercloud/hello-world

Check <https://hello.localhost>.

You can then stop the container with 

    $ docker stop hello-world
    hello-world

## Components

### Web service

#### in common words...

`traefik` is the your entry point: it acts as gateway on port 80. It is responsible for HTTPs redirection, and for any redirections you see fit (configuration samples are provided in ./etc folder) . 

    NAMES               IMAGE                           STATUS ago
    traefik             traefik:v2.0                  Up 14 minutes ago
