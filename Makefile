
.PHONY: up down build logs test clean

up:
	docker compose -f docker/docker-compose.yml up --build -d

down:
	docker compose -f docker/docker-compose.yml down

build:
	docker compose -f docker/docker-compose.yml build

logs:
	docker compose -f docker/docker-compose.yml logs -f

test:
	cd app/backend && python -m pytest -v

clean:
	docker compose -f docker/docker-compose.yml down -v
