# Small DevOps glossary

| Word | Simple meaning in this project |
| --- | --- |
| Frontend | The shop page you see in your browser |
| Backend or API | Code that receives requests and works with data |
| Database | The place that stores products and orders |
| Container | An isolated process running one part of the app |
| Image | The packaged files used to start a container |
| Docker Compose | The tool that starts our three containers together |
| Port | A number used to connect to a service, such as 8000 |
| Volume | Storage that can survive container deletion |
| Environment variable | A setting passed to a program when it starts |
| Secret | A private value, such as a database password |
| Git branch | A separate line of changes |
| Commit | A saved change with a unique ID |
| Pull request or PR | A request to review and merge a branch |
| CI | Automatic checks that run when code changes |
| Coverage | How much code the tests execute, not proof that all behavior is correct |
| Ruleset | GitHub rules that control changes to a branch |
| Rollback | Return to a previous working version |
| Smoke check | A quick check that the main parts start and respond |
| Infrastructure | Servers, networks, databases, and other hosting resources |
| Terraform | A tool that describes and manages infrastructure using code |
| Terraform state | The record Terraform uses to track resources; it may contain secrets |
| IAM | AWS permissions: who can do what |
| OIDC | A way for GitHub to request temporary AWS access without stored access keys |
| VPC and subnet | A private cloud network and a smaller section inside it |
| Security group | Network rules controlling allowed connections |
| ECR | AWS storage for container images |
| ECS / Fargate | AWS services for running containers without managing the servers |
| EKS | AWS-managed Kubernetes, with extra cost and operational choices |
| RDS | AWS-managed database service |
| HTTPS | Encrypted communication between the browser and the service |
| Snapshot | A saved copy of data at a point in time |
| RPO | How much recent data you can afford to lose |
| RTO | How long you can afford to take to restore service |
| ADR | A short record of a decision and why we made it |
