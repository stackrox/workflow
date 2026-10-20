import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


HELPER = Path(__file__).with_name("infra-sync-merge.py")
spec = importlib.util.spec_from_file_location("infra_sync_merge", HELPER)
merge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge)


def kubeconfig(path, cluster, context="default", user="admin"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({
        "apiVersion": "v1",
        "kind": "Config",
        "clusters": [{"name": cluster, "cluster": {"server": f"https://{cluster}.example.com"}}],
        "users": [{"name": user, "user": {"token": f"token-{cluster}"}}],
        "contexts": [{"name": context, "context": {"cluster": cluster, "user": user}}],
        "current-context": context,
    }))


@unittest.skipUnless(shutil.which("kubectl"), "kubectl is required")
class MergeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def test_same_context_name_keeps_both_clusters_and_credentials(self):
        first = self.root / "clusters" / "first" / "kubeconfig"
        second = self.root / "clusters" / "second" / "kubeconfig"
        kubeconfig(first, "first")
        kubeconfig(second, "second")

        result = merge.merge_configs([(first, True), (second, True)])

        self.assertEqual({item["name"] for item in result["contexts"]}, {"first", "second"})
        self.assertEqual(result["current-context"], "first")
        contexts = {item["name"]: item["context"] for item in result["contexts"]}
        users = {item["name"]: item["user"] for item in result["users"]}
        self.assertEqual(contexts["first"]["cluster"], "first")
        self.assertEqual(contexts["second"]["cluster"], "second")
        self.assertEqual(contexts["first"]["user"], "first/admin")
        self.assertEqual(contexts["second"]["user"], "second/admin")
        self.assertEqual(users[contexts["first"]["user"]]["token"], "token-first")
        self.assertEqual(users[contexts["second"]["user"]]["token"], "token-second")

    def test_extra_context_is_not_renamed_and_conflicting_references_are_distinct(self):
        infra = self.root / "clusters" / "first" / "kubeconfig"
        extra = self.root / "extra" / "kubeconfig"
        kubeconfig(infra, "first")
        kubeconfig(extra, "first", context="personal")

        result = merge.merge_configs([(infra, True), (extra, False)])

        self.assertEqual({item["name"] for item in result["contexts"]}, {"first", "personal"})
        self.assertEqual(len({item["context"]["cluster"] for item in result["contexts"]}), 2)
        self.assertEqual(len({item["context"]["user"] for item in result["contexts"]}), 2)

    def test_infra_user_is_prefixed_without_a_collision(self):
        infra = self.root / "clusters" / "first" / "kubeconfig"
        kubeconfig(infra, "first", user="unique")

        result = merge.merge_configs([(infra, True)])

        self.assertEqual(result["users"][0]["name"], "first/unique")
        self.assertEqual(result["contexts"][0]["context"]["user"], "first/unique")

    def test_context_collision_does_not_replace_existing_output(self):
        first = self.root / "clusters" / "first" / "kubeconfig"
        second = self.root / "clusters" / "second" / "kubeconfig"
        kubeconfig(first, "shared")
        kubeconfig(second, "shared")
        output = self.root / "kubeconfig"
        output.write_text("previous")

        with self.assertRaisesRegex(ValueError, "refusing to overwrite"):
            merge.write_config(merge.merge_configs([(first, True), (second, True)]), output)

        self.assertEqual(output.read_text(), "previous")
        self.assertFalse(Path(f"{output}.bkp").exists())

    def test_output_is_private_and_previous_config_is_backed_up(self):
        first = self.root / "clusters" / "first" / "kubeconfig"
        kubeconfig(first, "first")
        output = self.root / "kubeconfig"
        output.write_text("previous")

        merge.write_config(merge.merge_configs([(first, True)]), output)

        self.assertEqual(json.loads(output.read_text())["contexts"][0]["name"], "first")
        self.assertEqual(Path(f"{output}.bkp").read_text(), "previous")
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)
        parsed = subprocess.run(
            ["kubectl", "config", "view", "--kubeconfig", str(output), "--raw", "-o", "json"],
            check=True, capture_output=True, text=True,
        )
        self.assertEqual(json.loads(parsed.stdout)["contexts"][0]["name"], "first")


if __name__ == "__main__":
    unittest.main()
