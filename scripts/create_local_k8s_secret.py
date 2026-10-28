"""Create demo credentials directly in an isolated Kind cluster, never in Git/files."""
import argparse
import json
import secrets
import subprocess

p = argparse.ArgumentParser()
p.add_argument("--kubeconfig", required=True)
a = p.parse_args()
base = ["kubectl", "--kubeconfig", a.kubeconfig, "--context", "kind-cloudcart-lab", "-n", "cloudcart"]
if subprocess.run(base + ["get", "secret", "cloudcart-database"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    print("Existing secret preserved; its password must match the existing database volume.")
else:
    password = secrets.token_hex(32)
    secret = {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "cloudcart-database", "namespace": "cloudcart"}, "type": "Opaque", "stringData": {"POSTGRES_PASSWORD": password, "DATABASE_URL": f"postgresql+psycopg://cloudcart:{password}@shop-cloudcart-postgres:5432/cloudcart"}}
    subprocess.run(base + ["create", "-f", "-"], input=json.dumps(secret), text=True, check=True)
