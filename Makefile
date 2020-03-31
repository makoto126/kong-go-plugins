plugin = hello

default: build deploy

# create kong env
env:
	-docker network create kong-net

	docker run -d --name kong-database \
				--network=kong-net \
				-p 5432:5432 \
				-e "POSTGRES_USER=kong" \
				-e "POSTGRES_DB=kong" \
				-e "POSTGRES_PASSWORD=kong" \
				postgres:9.6

	sleep 5

	docker run --rm \
				--network=kong-net \
				-e "KONG_DATABASE=postgres" \
				-e "KONG_PG_HOST=kong-database" \
				-e "KONG_PG_PASSWORD=kong" \
				-e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
				kong:latest kong migrations bootstrap

	docker run -d --name kong \
				--network=kong-net \
				-e "KONG_DATABASE=postgres" \
				-e "KONG_PG_HOST=kong-database" \
				-e "KONG_PG_PASSWORD=kong" \
				-e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
				-e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
				-e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
				-e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
				-e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
				-e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
				-p 8000:8000 \
				-p 8443:8443 \
				-p 127.0.0.1:8001:8001 \
				-p 127.0.0.1:8444:8444 \
				kong:latest

	sleep 5

	curl -i -X POST \
			--url http://localhost:8001/services/ \
			--data 'name=example-service' \
			--data 'url=http://mockbin.org'

	curl -i -X POST \
			--url http://localhost:8001/services/example-service/routes \
			--data 'hosts[]=example.com'

# delete kong env
clean:
	-docker rm -f kong-database
	-docker rm -f kong
	-docker network rm kong-net

# build plugin to kong image
build:
	docker build -t kong:go-plugin --build-arg PLUGIN=$(plugin) .

# deploy plugin
deploy:
	-docker rm -f kong

	docker run -d --name kong \
				--network=kong-net \
				-e "KONG_DATABASE=postgres" \
				-e "KONG_PG_HOST=kong-database" \
				-e "KONG_PG_PASSWORD=kong" \
				-e "KONG_CASSANDRA_CONTACT_POINTS=kong-database" \
				-e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
				-e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
				-e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
				-e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
				-e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
				-e "KONG_GO_PLUGINS_DIR=/tmp/go-plugins" \
				-e "KONG_PLUGINS=$(plugin)" \
				-p 8000:8000 \
				-p 8443:8443 \
				-p 127.0.0.1:8001:8001 \
				-p 127.0.0.1:8444:8444 \
				kong:go-plugin

	sleep 5

	curl -i -X POST \
			--url http://localhost:8001/services/example-service/plugins/ \
			--data 'name=$(plugin)'

# test plugin
test:
	curl -i -X GET \
			--url http://localhost:8000/ \
			--header 'Host: example.com'