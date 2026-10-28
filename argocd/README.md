# Argo CD: deploy a reviewed Git version

Argo CD is a controller that compares Git with your cluster. In this project it
renders the same Helm chart tested locally. It does not build or push images.
CI checks a change; GitOps deploys an approved change. Credentials stay outside Git.

## Install the controller in a local test cluster

Use the private `$kube` path from [the Kubernetes guide](../docs/KUBERNETES.md).
The official release inspected for this work is v3.5.6. Review release notes before
upgrading. Download the pinned manifest into a private working folder, not the app chart:

```powershell
kubectl --kubeconfig $kube create namespace argocd
$installer = Join-Path $env:TEMP 'cloudcart-argocd-v3.5.6.yaml'
Invoke-WebRequest https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml -OutFile $installer
if ((Get-FileHash $installer -Algorithm SHA256).Hash -ne '846C644BC81CE5557DD9048757A9C7353378F25C5EB811C77D32A9E907823599') { throw 'Argo manifest checksum changed; review before applying' }
kubectl --kubeconfig $kube apply --server-side -n argocd -f $installer
kubectl --kubeconfig $kube -n argocd rollout status deployment/argocd-server --timeout=5m
kubectl --kubeconfig $kube -n argocd rollout status deployment/argocd-repo-server --timeout=5m
kubectl --kubeconfig $kube -n argocd rollout status statefulset/argocd-application-controller --timeout=5m
kubectl --kubeconfig $kube apply -f argocd/project.yaml
```

This installs cluster-wide controller permissions and CRDs, so do it only on the
isolated lab. Production Argo installation, SSO/RBAC, audit, backup, and upgrade
policies need their own reviewed platform change. Do not expose the admin UI
publicly. For local access, port-forward `service/argocd-server` port 24443 to
443 in namespace `argocd`. Retrieve the initial admin password privately from the
cluster using the official Argo instructions; never paste it into Git or chat.

## Local Application

1. Deploy the chart and create its Secret as described in the Kubernetes guide.
2. Copy `application-local.yaml` to a working file outside Git.
3. Replace `REPLACE_WITH_REVIEWED_GIT_COMMIT` with the full commit containing
   the chart. Push that commit so Argo can fetch it. Local images must already
   be loaded into the Kind node; the values-local profile is only for this lab.
4. Apply the working file with `kubectl --kubeconfig $kube apply -f YOUR_FILE`.
5. Request a manual sync in the local Argo UI. Verify both `Synced` and `Healthy`,
   then check frontend and readiness using port-forward.

Helm's old local release history may still exist after this handoff, but Argo
owns desired state now. Do not keep changing both. Argo uses Helm as a renderer,
not as the Helm release manager.

## Production Application

`application.yaml` is a fail-closed template. It points to the production values
file, which must be filled through a reviewed PR. Set a full reviewed commit ID;
do not track `HEAD` or a moving branch for a controlled release. Supply real
image digests and external credentials outside Git. Create the destination
namespace and TLS/DB/image-pull Secrets through the approved platform process.

The AppProject accepts only this repository and the `cloudcart` namespace.
It cannot create cluster-scoped resources, namespaces, roles, or Secrets. It can
manage only the listed application resource types. There is no automatic sync,
automatic pruning, or cascading-deletion finalizer. A sync is an explicit action.
Do not enable automatic deletion for a database lab without a recovery drill.

Ingress access restrictions and Secret values are not created by Argo templates.
A successful render is not evidence of safe public access or a working deployment.

## Recovery

Revert the Git change, review it, update the pinned target commit, then manually
sync. Do not assume an image tag still refers to its old bytes. Check readiness
and data after every rollback. Application rollback does not restore the database.
Deleting this Application has no cascading finalizer and should not be used as
an application teardown. Remove resources only after reviewing retained data.

Official references: [Helm rendering](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/),
[sync and pruning](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/).
