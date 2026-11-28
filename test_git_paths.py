import contextlib
from pathlib import Path
import subprocess
import tempfile
import unittest

from add_new_entry import Constants, GitManager


class GitPathTests(unittest.TestCase):
    def test_untracked_solidity_names_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            subprocess.run(['git', 'init', '-q'], check=True)
            constants = Constants()
            Path(constants.SRC_TEST_DIR).mkdir(parents=True)
            names = ['With Space_exp.sol', 'New\nLine_exp.sol', '引号_exp.sol', 'Quote"_exp.sol']
            paths = [str(Path(constants.SRC_TEST_DIR, name)) for name in names]
            for path in paths:
                Path(path).write_text('// fixture\n', encoding='utf-8')
            self.assertEqual(set(GitManager(constants).get_uncommitted_sol_files()), set(paths))


if __name__ == '__main__':
    unittest.main()
