"""Check rendered deployment safety without a cluster or credentials."""
from pathlib import Path
import yaml

root = Path("kubernetes/rendered")
objects = [obj for path in root.rglob("*.yaml") for obj in yaml.safe_load_all(path.read_text()) if obj]
assert objects
assert not any(obj["kind"] == "Secret" for obj in objects), "Never render secret values into Git"
deployments = [obj for obj in objects if obj["kind"] == "Deployment"]
assert len(deployments) == 2
for obj in deployments:
    spec = obj["spec"]["template"]["spec"]
    assert spec["automountServiceAccountToken"] is False
    assert spec["securityContext"]["runAsNonRoot"]
    for container in spec["containers"]:
        assert container["securityContext"]["readOnlyRootFilesystem"]
        assert container["securityContext"]["allowPrivilegeEscalation"] is False
        assert container["securityContext"]["capabilities"]["drop"] == ["ALL"]
        assert all(key in container for key in ("startupProbe", "readinessProbe", "livenessProbe", "resources"))
project = yaml.safe_load(Path("argocd/project.yaml").read_text())
assert project["spec"]["clusterResourceWhitelist"] == []
assert project["spec"]["destinations"][0]["namespace"] == "cloudcart"
app = yaml.safe_load(Path("argocd/application.yaml").read_text())
assert "automated" not in app["spec"]["syncPolicy"]
assert not app["metadata"].get("finalizers")
assert app["spec"]["project"] == project["metadata"]["name"]
print("Rendered safety and Argo CD scope checks: PASS")
