import pathlib
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ManifestContract(unittest.TestCase):
    def test_manifest_defines_complete_container_contract(self):
        manifest = yaml.safe_load((ROOT / "manifest.yaml").read_text())

        self.assertEqual(manifest["schema"], "orca.app-image/v2")
        self.assertEqual(manifest["slug"], "stirling-pdf")
        self.assertEqual(manifest["application"]["version"], "2.14.2")
        self.assertEqual(manifest["base_os"], {"distribution": "ubuntu", "release": "24.04"})
        self.assertEqual(manifest["architecture"], "x86_64")
        self.assertEqual(manifest["instance_type"], "container")
        self.assertEqual(manifest["minimum_resources"], {"cpu": 2, "memory_mib": 2048, "storage_gib": 10})
        self.assertEqual(manifest["network"]["default_policy"], "private")
        self.assertEqual(manifest["exposer"]["endpoints"], [{
            "name": "web", "protocol": "http", "target_port": 8080,
            "default_public": True, "tls": "automatic", "health_path": "/api/v1/info/status",
        }])
        self.assertEqual(manifest["persistent_paths"], [{
            "path": "/var/lib/stirling-pdf", "volume": "stirling-data", "required": True,
        }])
        self.assertEqual(manifest["volume_expectations"]["stirling-data"]["owner"], "988:988")
        self.assertEqual(manifest["first_boot_credentials"]["behavior"], "none-login-disabled")
        self.assertEqual(manifest["upstream"]["version_strategy"], "github-releases")
        self.assertEqual(manifest["branding"]["local_path"], "assets/logo.png")
        self.assertTrue(manifest["branding"]["logo_source_url"].startswith("https://github.com/Stirling-Tools/"))
        self.assertTrue(manifest["build"]["ready"])

    def test_build_recipe_is_pinned_and_attaches_data_before_first_boot(self):
        build = (ROOT / "recipes/build.sh").read_text()
        provision = (ROOT / "recipes/provision.sh").read_text()

        self.assertIn("ubuntu:24.04", build)
        self.assertIn("--storage \"$STORAGE\"", build)
        self.assertIn("size=10GiB", build)
        self.assertIn("root,size=\"$ROOT_SIZE\"", build)
        self.assertLess(build.index("device add"), build.index(" start "))
        self.assertIn("20159880475e8fc00483423405b44c48058557e3ff197baa87ebacf5d22d37c2", provision)
        self.assertIn("sha256sum --check", provision)
        self.assertIn("--gid 988", provision)
        self.assertIn("--uid 988", provision)
        self.assertIn("User=stirling-pdf", provision)
        self.assertIn("ExecStartPre=+/usr/local/libexec/stirling-volume-init", provision)
        self.assertIn("NoNewPrivileges=true", provision)

    def test_provision_pins_java_25_runtime_required_by_release_jar(self):
        provision = (ROOT / "recipes/provision.sh").read_text()

        self.assertNotIn("openjdk-21-jre-headless", provision)
        self.assertIn("OpenJDK25U-jre_x64_linux_hotspot_25.0.4_7.tar.gz", provision)
        self.assertIn("aed3915f8facc0c80733ab2448bb0df4b494a36a2c5759e9a6e1eb979720f2b3", provision)
        self.assertIn("/opt/java/bin/java", provision)

    def test_service_registers_tini_as_child_subreaper(self):
        provision = (ROOT / "recipes/provision.sh").read_text()

        self.assertIn("ExecStart=/usr/bin/tini -s --", provision)

    def test_volume_initializer_owns_pipeline_parent_before_nested_directories(self):
        provision = (ROOT / "recipes/provision.sh").read_text()

        self.assertIn("  /var/lib/stirling-pdf/pipeline \\\n", provision)

    def test_acceptance_recipe_validates_functional_readiness_and_persistence(self):
        acceptance = (ROOT / "recipes/acceptance.sh").read_text()

        self.assertIn("/api/v1/info/status", acceptance)
        self.assertIn("python3 -c", acceptance)
        self.assertIn("status", acceptance)
        self.assertIn("/api/v1/info", acceptance)
        self.assertNotIn("http://127.0.0.1:8080/api/v1/info \\\n", acceptance)
        self.assertNotIn("http://127.0.0.1:8080/ | grep", acceptance)
        self.assertIn("orca-persistence-probe", acceptance)
        self.assertIn("systemctl is-active --quiet stirling-pdf", acceptance)


if __name__ == "__main__":
    unittest.main(verbosity=2)
