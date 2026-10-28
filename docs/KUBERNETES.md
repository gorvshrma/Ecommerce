# Kubernetes, Helm, and Argo CD: start here

This is an alternative deployment path for learning Kubernetes. It does not
create EKS or change the ECS Terraform configuration. Do not deploy both cloud
runtimes by accident. The app's shopping features and local Compose ports stay unchanged.

## What each tool does

- Kubernetes keeps containers running and gives them internal service addresses.
- Helm fills in a reusable set of Kubernetes files using a values file.
- Argo CD reads that chart from Git and applies the reviewed version to a cluster.

`helm/cloudcart` is the source. `kubernetes/rendered` is a generated local-demo
copy, not a second hand-maintained configuration. Never put passwords into chart
values or generated manifests. Kubernetes Secrets are base64 encoded, not
inherently encrypted. Production needs encryption at rest, RBAC, and an approved
secret manager/operator; none is provisioned by this chart.

## Local requirements

Install Docker, Kind, kubectl, Python, and Helm 3.17.3. Use a separate cluster
named `cloudcart-lab`, and store its kubeconfig outside Git. The commands below
use PowerShell and a file in your home folder. Keep the file private.

```powershell
$kube = Join-Path $HOME 'cloudcart.kubeconfig'
kind create cluster --name cloudcart-lab --config kubernetes/kind.yaml --kubeconfig $kube --wait 120s
```

If Docker uses cgroup v1, modern Kubernetes refuses to start by default. Prefer
upgrading the Docker host to cgroup v2. For a disposable local exercise only,
use `--config kubernetes/kind-legacy-cgroup-v1.yaml --image kindest/node:v1.35.0`
instead. That file opts into Kubernetes' temporary legacy mode; never use it in
production. Delete a failed empty cluster before retrying. Do not delete an
existing cluster that has needed data.

## Build, load, and deploy the demo

The frontend is built for API port 28000. This avoids the existing Compose
ports 3000 and 8000. Build from the repository root:

```powershell
docker build -t docker-backend:latest app/backend
docker build --build-arg VITE_API_URL=http://localhost:28000 -t cloudcart-k8s-frontend:local app/frontend
kind load docker-image --name cloudcart-lab docker-backend:latest cloudcart-k8s-frontend:local postgres:16-alpine
kubectl --kubeconfig $kube apply -f kubernetes/namespace.yaml
python scripts/create_local_k8s_secret.py --kubeconfig $kube
helm upgrade --install shop helm/cloudcart -f helm/cloudcart/values-local.yaml --namespace cloudcart --kubeconfig $kube --wait --timeout 5m
kubectl --kubeconfig $kube -n cloudcart get pods,pvc
```

Pull `postgres:16-alpine` first if it is not already local. The Python helper
creates a random password directly in the isolated cluster, without writing or
printing it. It preserves an existing Secret. Its connection address assumes
release `shop` and namespace `cloudcart`; do not rename the release casually.
The optional PostgreSQL StatefulSet is for the local lab only, not a managed,
replicated production database.

Open two additional terminals and use the same private kubeconfig path:

```powershell
kubectl --kubeconfig $kube -n cloudcart port-forward service/shop-cloudcart-frontend 23000:8080
```

```powershell
kubectl --kubeconfig $kube -n cloudcart port-forward service/shop-cloudcart-backend 28000:8000
```

Open http://localhost:23000 and http://localhost:28000/ready. Expect the shop
and database `connected`. `/health` and `/api/products` should respond as well.
Port-forward binds localhost by default; do not expose it publicly.

## Use plain Kubernetes files instead

Choose Helm OR plain manifests for initial installation, not both. To regenerate:

```powershell
helm template shop helm/cloudcart -f helm/cloudcart/values-local.yaml -n cloudcart --output-dir kubernetes/rendered
```

After creating the namespace and external Secret, use
`kubectl --kubeconfig $kube -n cloudcart apply -R -f kubernetes/rendered`.
Use the same port-forward commands. Never hand-edit generated files: edit the
chart and regenerate. CI rejects generated-file drift.

## What is hardened

App containers run as non-root, drop capabilities, block privilege escalation,
and have read-only root filesystems. The frontend uses an explicit Nginx config
and writable temporary directory. Probes distinguish process health from DB
readiness. CPU/memory requests and limits are set. No pod receives an automatic
service-account token. Default-deny network policies allow DNS, ingress-controller
traffic, and backend-to-database connections. Frontend replicas above one have
a disruption budget. Data claims are retained when the local database stops.

Default Kind networking does not necessarily enforce NetworkPolicy. Rendering
policies is not proof of enforcement: use a policy-capable CNI and test allowed
and denied traffic before any production claim. DNS labels and ingress namespace
must match your cluster. This lab has not added autoscaling or metrics-server.

## Production profile: deliberate prerequisites

`values-production.yaml` intentionally fails until you provide real reviewed
values. It requires digest-pinned images, an external database, HTTPS ingress,
a private DB CIDR (/16 to /32), and confirmation that access controls were tested. Use a
supported organization-approved ingress controller; none is installed here.
Set its namespace in the network-policy values. Configure the controller's
viewer allowlist or authentication through reviewed annotations/policies before
acknowledging `accessControlsVerified`. The boolean is an acknowledgement, not
an authentication system.

Build the frontend for the actual HTTPS API URL. Store a TLS-verified PostgreSQL
DSN under key `DATABASE_URL` in the existing Secret. Use a restricted DB user and
a backend image containing the RDS/provider CA bundle. Supply registry access
through approved node identity or external image-pull Secrets. Do not commit
credentials. TLS certificates, DNS, external-secret controllers, ingress, image
publishing, schema migration, and a real restore test remain separate prerequisites.

Only one backend replica is allowed until startup/migration coordination is
implemented. A rolling update can briefly overlap backend versions: review schema
compatibility. Do not describe this app as highly available or ready for real
customers. The production-check fixture uses fake images and is only a CI test.

## Argo CD is the next handoff

Follow [the GitOps guide](../argocd/README.md). Once Argo owns these resources,
stop using `helm upgrade`, `helm rollback`, or plain `kubectl apply` to change
them. Change Git, review the PR, then sync the approved commit.

## Rollback and cleanup

For a Helm-only installation, inspect `helm history shop -n cloudcart --kubeconfig $kube`
and use `helm rollback shop REVISION -n cloudcart --kubeconfig $kube --wait`.
Replace `REVISION` with an actual working revision. This rolls back code, not data.
For Argo CD, revert the bad Git change, point the Application to the reviewed
working commit, and manually sync. Keep pruning off while learning.

`helm uninstall shop -n cloudcart --kubeconfig $kube` removes a Helm-managed app
but retains the database claim. Keep its matching Secret. Deleting the namespace,
PVC, or Kind cluster can destroy data; do that only for a disposable lab after
saving anything you need. Exact disposable-cluster teardown:

```powershell
kind delete cluster --name cloudcart-lab
```

This affects only this named local cluster, not Compose or AWS. Retained Docker
images still take disk space. No cloud resource cleanup is required for this lab.
