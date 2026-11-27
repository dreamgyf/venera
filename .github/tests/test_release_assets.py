import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "release_assets", Path(__file__).parents[1] / "scripts/upload-release-assets.py"
)
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class ReleaseAssetsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        previous = os.getcwd()
        self.addCleanup(os.chdir, previous)
        os.chdir(temporary.name)
        Path("outputs").mkdir()
        environment = patch.dict(os.environ, {
            "GITHUB_REPOSITORY": "example/venera", "RELEASE_TAG": "v1.6.4",
            "GITHUB_RUN_ID": "123",
        })
        environment.start()
        self.addCleanup(environment.stop)

    def metadata(self, assets=(), body="Original release notes"):
        return json.dumps({"assets": [{"name": name} for name in assets], "body": body})

    def test_existing_assets_are_preserved_and_ipa_is_excluded(self):
        for name in ("existing.deb", "new.deb", "existing.ipa"):
            Path("outputs", name).write_bytes(b"package")
        with patch.object(publisher.subprocess, "check_output", return_value=self.metadata(["existing.deb"])), \
                patch.object(publisher.subprocess, "run") as run:
            publisher.main()
        run.assert_called_once_with([
            "gh", "release", "upload", "v1.6.4", "outputs/new.deb",
            "--repo", "example/venera",
        ], check=True)

    def test_empty_artifact_directory_fails(self):
        with patch.object(publisher.subprocess, "check_output", return_value=self.metadata()), \
                patch.object(publisher.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "No successful"):
                publisher.main()
        run.assert_not_called()

    def test_upload_failure_is_not_reported_as_success(self):
        Path("outputs/new.deb").write_bytes(b"package")
        with patch.object(publisher.subprocess, "check_output", return_value=self.metadata()), \
                patch.object(publisher.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "gh")):
            with self.assertRaises(subprocess.CalledProcessError):
                publisher.main()

    def test_unsigned_notes_preserve_existing_description(self):
        for name in ("venera-unsigned.apk", "venera-adhoc.dmg"):
            Path("outputs", name).write_bytes(b"package")
        edits = []

        def capture(command, **kwargs):
            if command[:3] == ["gh", "release", "edit"]:
                edits.append(Path(command[-1]).read_text())

        with patch.object(publisher.subprocess, "check_output", return_value=self.metadata()), \
                patch.object(publisher.subprocess, "run", side_effect=capture):
            publisher.main()
        self.assertEqual(len(edits), 1)
        self.assertTrue(edits[0].startswith("Original release notes"))
        self.assertIn("require signing before installation", edits[0])
        self.assertIn("without a Developer ID", edits[0])
        self.assertIn("/actions/runs/123", edits[0])


if __name__ == "__main__":
    unittest.main()
