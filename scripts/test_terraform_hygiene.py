"""Regression checks for accidental state/plan commits; no AWS calls."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from check_terraform_hygiene import is_private, private_artifact


class TerraformHygieneTests(unittest.TestCase):
    def test_private_names_and_safe_examples(self):
        for name in ("state.tfstate", "state.tfstate.backup", "release.tfplan.json", "plan.out", "dev.tfvars", "backend.hcl", ".terraform/providers/plugin"):
            self.assertTrue(is_private("terraform/" + name), name)
        for name in (".terraform.lock.hcl", "terraform.tfvars.example", "backend.hcl.example", "tests/security.tftest.hcl"):
            self.assertFalse(is_private("terraform/" + name), name)

    def test_renamed_state_and_plan(self):
        with tempfile.TemporaryDirectory(prefix=".terraform-hygiene-", dir=Path.cwd()) as temp:
            file = Path(temp) / "renamed.txt"
            file.write_text(json.dumps({"terraform_version": "test", "serial": 0, "lineage": "mock"}))
            self.assertTrue(private_artifact(file))
            file.write_text(json.dumps({"terraform_version": "test", "format_version": "1", "planned_values": {}}))
            self.assertTrue(private_artifact(file))
            file.write_text(json.dumps({"name": "ordinary", "version": "1"}))
            self.assertFalse(private_artifact(file))

    def test_renamed_binary_plan(self):
        with tempfile.TemporaryDirectory(prefix=".terraform-hygiene-", dir=Path.cwd()) as temp:
            file = Path(temp) / "renamed.data"
            with zipfile.ZipFile(file, "w") as archive:
                archive.writestr("tfplan", "mock only")
            self.assertTrue(private_artifact(file))


if __name__ == "__main__":
    unittest.main()
