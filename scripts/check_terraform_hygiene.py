"""Fail CI if Terraform state, saved plans, or private inputs are tracked."""
from pathlib import Path, PurePosixPath
import fnmatch
import json
import zipfile
import re
import subprocess
import sys

FORBIDDEN = (
    "*.tfstate*", "*.tflock", "*.tfplan", "*.tfplan.*", "*.plan",
    "tfplan", "tfplan.*", "plan.out", "*.tfvars", "*.tfvars.json",
    "*.tfbackend", "backend.hcl", "backend.*.hcl", ".terraform.tfstate.lock.info",
    "crash.log", "crash.*.log", "*.secret", "*.secret.json",
)


def is_private(path):
    name = PurePosixPath(path).name
    return ".terraform" in PurePosixPath(path).parts or any(
        fnmatch.fnmatch(name, pattern) for pattern in FORBIDDEN
    )


def private_artifact(path):
    """Also catch renamed Terraform JSON state/plan files and ZIP plan archives."""
    file = Path(path)
    if not file.is_file():
        return False
    with file.open("rb") as stream:
        prefix = stream.read(4)
    if prefix.startswith(b"PK") and zipfile.is_zipfile(file):
        with zipfile.ZipFile(file) as archive:
            return "tfplan" in archive.namelist()
    if prefix.lstrip().startswith(b"{"):
        try:
            data = json.loads(file.read_text(encoding="utf-8"))
        except (ValueError, UnicodeError):
            return False
        if isinstance(data, dict):
            return (
                {"terraform_version", "serial", "lineage"}.issubset(data)
                or ("terraform_version" in data and "format_version" in data and any(
                    key in data for key in ("planned_values", "resource_changes", "prior_state")
                ))
            )
    return False


def main():
    tracked = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
    problems = [path for path in tracked if path and (is_private(path) or private_artifact(path))]
    probes = ["terraform/application/" + name for name in (
        "terraform.tfstate", "terraform.tfstate.backup", "errored.tfstate",
        "release.tfplan", "release.tfplan.json", "tfplan", "plan.out",
        "terraform.tfvars", "inputs.auto.tfvars.json", "backend.hcl",
        "backend.private.hcl", "dev.tfbackend", "database.secret",
        ".terraform/providers/cache", ".terraform.tfstate.lock.info",
    )]
    ignored = subprocess.run(
        ["git", "check-ignore", "--no-index", "--stdin", "-z"],
        input=("\0".join(probes) + "\0").encode(), capture_output=True,
    )
    if ignored.returncode not in (0, 1):
        print("git check-ignore failed", file=sys.stderr)
        return 1
    problems += [path + " (not ignored)" for path in probes if path not in ignored.stdout.decode().split("\0")]
    for path in ("terraform/bootstrap/.terraform.lock.hcl", "terraform/platform/.terraform.lock.hcl", "terraform/application/.terraform.lock.hcl"):
        if subprocess.run(["git", "check-ignore", "--no-index", "--quiet", path]).returncode == 0:
            problems.append(path + " (provider lock must be trackable)")
    assert not is_private("terraform/application/terraform.tfvars.example")
    assert not is_private("terraform/application/backend.hcl.example")
    assert not is_private("terraform/application/.terraform.lock.hcl")
    for stack in ("bootstrap", "platform", "application"):
        source = Path("terraform", stack, "versions.tf").read_text(encoding="utf-8")
        if not re.search(r'backend\s+"s3"\s*\{', source):
            problems.append(stack + " (committed root must use S3 state)")
    if problems:
        print("Do not commit Terraform state, plans, or private inputs:", file=sys.stderr)
        print("\n".join(problems), file=sys.stderr)
        return 1
    print("Terraform Git hygiene: PASS (tracked files and ignore rules checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
