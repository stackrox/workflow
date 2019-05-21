import os
import unittest


class TestAllSymlinksUpToDate(unittest.TestCase):

    def test_all_symlinks_match_file(self):
        git_root = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), ".."))

        bin_dir = os.path.join(git_root, "bin")
        scripts_dir = os.path.join(git_root, "scripts")
        for file in os.listdir(bin_dir):
            full_path = os.path.join(bin_dir, file)
            resolved_path = os.path.realpath(full_path)
            self.assertTrue(resolved_path.startswith(scripts_dir), f"{resolved_path} must be in {scripts_dir}")
            self.assertTrue(os.path.isfile(resolved_path), f"{resolved_path} pointed to by {full_path} not found")
            self.assertTrue(os.access(resolved_path, os.X_OK), f"{resolved_path} not executable")

if __name__ == '__main__':
    unittest.main()
