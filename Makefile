
.PHONY: up down build logs test clean

COMPOSE = docker compose --env-file .env -f docker/docker-compose.yml

up:
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

test:
	cd app/backend && python -m pytest -v

clean:
	$(COMPOSE) down -v
