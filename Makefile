.PHONY: help init setup dev test lint docker-init docker-setup docker-up docker-down docker-logs docker-ps \
        vehicle-gor3a-check vehicle-gor3a-import vehicle-vehiclesdb-check \
        vehicle-vehiclesdb-import vehicle-index docker-vehicle-gor3a-check \
        docker-vehicle-gor3a-import docker-vehicle-vehiclesdb-check \
        docker-vehicle-vehiclesdb-import docker-vehicle-index

help: ## Mostrar los comandos disponibles
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-32s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Instalar dependencias y preparar la aplicación
	mise install
	mise exec -- bundle install
	mise exec -- bin/rails db:prepare
	mise exec -- bin/rails db:seed
	mise exec -- bundle exec autofacts install

setup: init ## Alias de init

dev: ## Iniciar Rails y Sidekiq
	mise exec -- bin/dev

test: ## Ejecutar las pruebas
	mise exec -- bundle exec rspec
	mise exec -- bin/rails test

lint: ## Comprobar el estilo Ruby
	mise exec -- bin/rubocop

docker-init: docker-up ## Preparar e iniciar Docker

docker-setup: docker-init ## Alias de docker-init

docker-up: ## Construir e iniciar Docker
	docker compose --env-file .env.docker build web
	docker compose --env-file .env.docker up --no-build -d

docker-down: ## Detener Docker
	docker compose --env-file .env.docker down

docker-logs: ## Mostrar los registros Docker
	docker compose --env-file .env.docker logs -f

docker-ps: ## Mostrar el estado de Docker
	docker compose --env-file .env.docker ps

vehicle-gor3a-check: ## Validar gor3a sin importar
	mise exec -- bin/rails automotive_catalog:import SOURCE=gor3a SQLITE_PATH=data/gor3a.sqlite

vehicle-gor3a-import: ## Importar gor3a
	mise exec -- bin/rails automotive_catalog:import SOURCE=gor3a SQLITE_PATH=data/gor3a.sqlite APPLY=true

vehicle-vehiclesdb-check: ## Validar VehiclesDB sin importar
	mise exec -- bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=data/vehiclesdb.sqlite VEHICLESDB_ATTRIBUTION_PATH=data/ATTRIBUTION.md

vehicle-vehiclesdb-import: ## Importar VehiclesDB
	mise exec -- bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=data/vehiclesdb.sqlite VEHICLESDB_ATTRIBUTION_PATH=data/ATTRIBUTION.md APPLY=true

vehicle-index: ## Reconstruir el índice de vehículos
	mise exec -- bin/rails automotive_catalog:rebuild_vehicle_search

docker-vehicle-gor3a-check: ## Validar gor3a en Docker sin importar
	docker compose --env-file .env.docker run --rm import bin/rails automotive_catalog:import SOURCE=gor3a SQLITE_PATH=/vehicle-data/gor3a.sqlite

docker-vehicle-gor3a-import: ## Importar gor3a en Docker
	docker compose --env-file .env.docker run --rm import bin/rails automotive_catalog:import SOURCE=gor3a SQLITE_PATH=/vehicle-data/gor3a.sqlite APPLY=true

docker-vehicle-vehiclesdb-check: ## Validar VehiclesDB en Docker sin importar
	docker compose --env-file .env.docker run --rm import bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=/vehicle-data/vehiclesdb.sqlite VEHICLESDB_ATTRIBUTION_PATH=/vehicle-data/ATTRIBUTION.md

docker-vehicle-vehiclesdb-import: ## Importar VehiclesDB en Docker
	docker compose --env-file .env.docker run --rm import bin/rails automotive_catalog:import SOURCE=vehiclesdb SQLITE_PATH=/vehicle-data/vehiclesdb.sqlite VEHICLESDB_ATTRIBUTION_PATH=/vehicle-data/ATTRIBUTION.md APPLY=true

docker-vehicle-index: ## Reconstruir el índice de vehículos en Docker
	docker compose --env-file .env.docker run --rm import bin/rails automotive_catalog:rebuild_vehicle_search
