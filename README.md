
# Cloud-Native E-Commerce Platform

A production-style 3-tier DevOps portfolio project built around a deliberately small e-commerce use case.

## Architecture

```text
Browser
   |
   v
React Frontend
   |
   | REST/JSON
   v
FastAPI Backend
   |
   | SQL
   v
PostgreSQL
```

## Current Features

- Product catalog
- Shopping cart
- Order creation
- Inventory reduction
- PostgreSQL persistence
- `/health`, `/ready`, `/info`, `/metrics`
- Dockerized frontend/backend/database
- Docker Compose networking
- Prometheus metrics
- Backend tests
- Runtime deployment metadata

## Run

From the repository root:

```bash
docker compose -f docker/docker-compose.yml up --build
```

Open:

- Frontend: http://localhost:3000
- Swagger API: http://localhost:8000/docs
- Health: http://localhost:8000/health
- Readiness: http://localhost:8000/ready
- Metrics: http://localhost:8000/metrics

Stop:

```bash
docker compose -f docker/docker-compose.yml down
```

Reset the database:

```bash
docker compose -f docker/docker-compose.yml down -v
```

## DevOps Roadmap

Next:
1. GitHub Actions CI
2. Trivy + Checkov
3. Amazon ECR
4. Terraform VPC/IAM/EKS/RDS
5. Kubernetes workloads
6. Helm
7. Argo CD
8. Prometheus/Grafana
9. HPA/PDB/NetworkPolicy
10. Failure + rollback scenarios
