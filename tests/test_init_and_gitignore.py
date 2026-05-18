"""
Tests for init.lua and .gitignore — Entry point and repository configuration.

Files under test:
  init.lua   — Neovim entry point; module load order
  .gitignore — Ignored file patterns

This PR's key changes:
  - init.lua completely rewritten: simplified load order (core.options →
    core.autocmds → core.treesitter → plugins → core.keymaps)
  - .gitignore: lazy-lock.json added on the same line as luac.out (formatting
    change), ensuring the lock file is not committed to version control.
"""

import os
import re
import unittest

REPO_ROOT = os.path.join(os.path.dirname(__file__), "..")


def read_file(name):
    """Return the contents of a file relative to the repo root."""
    path = os.path.join(REPO_ROOT, name)
    with open(path, encoding="utf-8") as fh:
        return fh.read()


# ============================================================================
# Tests for init.lua
# ============================================================================

class TestInitLua(unittest.TestCase):
    """Tests for init.lua — Neovim entry point and module load order."""

    def setUp(self):
        self.content = read_file("init.lua")

    def test_file_exists(self):
        """init.lua must exist at the repository root."""
        self.assertTrue(os.path.exists(os.path.join(REPO_ROOT, "init.lua")))

    def test_mapleader_set(self):
        """mapleader must be set before any plugin loads."""
        self.assertIn('vim.g.mapleader      = " "', self.content)

    def test_maplocalleader_set(self):
        """maplocalleader must be set before any plugin loads."""
        self.assertIn('vim.g.maplocalleader = "\\\\"', self.content)

    def test_core_options_loaded(self):
        """core.options must be loaded."""
        self.assertIn('require("core.options")', self.content)

    def test_core_autocmds_loaded(self):
        """core.autocmds must be loaded."""
        self.assertIn('require("core.autocmds")', self.content)

    def test_core_treesitter_loaded(self):
        """core.treesitter must be loaded."""
        self.assertIn('require("core.treesitter")', self.content)

    def test_plugins_loaded(self):
        """plugins module (lazy.nvim bootstrap) must be loaded."""
        self.assertIn('require("plugins")', self.content)

    def test_core_keymaps_loaded(self):
        """core.keymaps must be loaded."""
        self.assertIn('require("core.keymaps")', self.content)

    def test_load_order_leader_before_everything(self):
        """Leader keys must be set BEFORE any require() calls."""
        leader_idx = self.content.find('vim.g.mapleader')
        first_require_idx = self.content.find('require(')
        self.assertGreater(
            first_require_idx, leader_idx,
            "vim.g.mapleader must appear before the first require() call"
        )

    def test_load_order_options_before_autocmds(self):
        """core.options must be loaded before core.autocmds."""
        options_idx = self.content.find('require("core.options")')
        autocmds_idx = self.content.find('require("core.autocmds")')
        self.assertGreater(
            autocmds_idx, options_idx,
            "core.options must be required before core.autocmds"
        )

    def test_load_order_autocmds_before_treesitter(self):
        """core.autocmds must be loaded before core.treesitter."""
        autocmds_idx = self.content.find('require("core.autocmds")')
        treesitter_idx = self.content.find('require("core.treesitter")')
        self.assertGreater(
            treesitter_idx, autocmds_idx,
            "core.autocmds must be required before core.treesitter"
        )

    def test_load_order_treesitter_before_plugins(self):
        """core.treesitter must be loaded before plugins."""
        treesitter_idx = self.content.find('require("core.treesitter")')
        plugins_idx = self.content.find('require("plugins")')
        self.assertGreater(
            plugins_idx, treesitter_idx,
            "core.treesitter must be required before plugins"
        )

    def test_load_order_plugins_before_keymaps(self):
        """plugins must be loaded before core.keymaps (plugins define textobj APIs)."""
        plugins_idx = self.content.find('require("plugins")')
        keymaps_idx = self.content.find('require("core.keymaps")')
        self.assertGreater(
            keymaps_idx, plugins_idx,
            "plugins must be required before core.keymaps"
        )

    def test_no_old_config_module(self):
        """Old config.* modules must not be referenced (they were deleted)."""
        self.assertNotIn('require("config.', self.content)

    def test_no_old_global_notify(self):
        """Old _G.notify helper must not be defined (removed in this PR)."""
        self.assertNotIn("_G.notify", self.content)

    def test_no_feature_flags(self):
        """Old enable_keymaps / enable_autocmds feature flags must be removed."""
        self.assertNotIn("enable_keymaps", self.content)
        self.assertNotIn("enable_autocmds", self.content)

    def test_ui2_enable_called(self):
        """vim._core.ui2.enable must be called for 0.12 UI features."""
        self.assertIn("vim._core.ui2", self.content)
        self.assertIn(".enable(", self.content)

    def test_only_expected_requires(self):
        """init.lua must only require specific modules (not arbitrary ones)."""
        requires = re.findall(r'require\(([^)]+)\)', self.content)
        allowed = {
            "'vim._core.ui2'",
            '"core.options"',
            '"core.autocmds"',
            '"core.treesitter"',
            '"plugins"',
            '"core.keymaps"',
        }
        for req in requires:
            # Check the call pattern: require('...') or require("...")
            # We want to verify each require is in our expected set
            normalized = req.strip()
            self.assertIn(
                normalized, allowed,
                f"Unexpected require({normalized}) in init.lua"
            )

    def test_all_five_core_modules_required(self):
        """All five core modules + plugins must be explicitly required."""
        expected_modules = [
            '"core.options"',
            '"core.autocmds"',
            '"core.treesitter"',
            '"plugins"',
            '"core.keymaps"',
        ]
        for mod in expected_modules:
            self.assertIn(
                f"require({mod})", self.content,
                f"require({mod}) not found in init.lua"
            )

    def test_file_is_concise(self):
        """init.lua should be concise — no more than 20 non-empty, non-comment lines."""
        lines = self.content.splitlines()
        code_lines = [
            l for l in lines
            if l.strip() and not l.strip().startswith("--")
        ]
        self.assertLessEqual(
            len(code_lines), 20,
            f"init.lua has {len(code_lines)} code lines — it should be concise"
        )


class TestInitLuaLoadOrderRegression(unittest.TestCase):
    """
    Regression tests for the PR's key change: init.lua was completely rewritten
    from the old flag-based approach to a simple, direct load sequence.
    These tests ensure the new behaviour is correct and the old pattern is gone.
    """

    def setUp(self):
        self.content = read_file("init.lua")

    def test_no_conditional_module_loading(self):
        """Modules must not be conditionally loaded with if/then flags."""
        # The old pattern used 'if enable_keymaps then require(...)' etc.
        self.assertNotIn("if enable_", self.content)

    def test_mapleader_set_at_top(self):
        """Leader key assignment must be near the top of the file."""
        lines = self.content.splitlines()
        # Find the line number of mapleader assignment (1-indexed)
        leader_line = None
        for i, line in enumerate(lines, 1):
            if 'vim.g.mapleader' in line:
                leader_line = i
                break
        self.assertIsNotNone(leader_line)
        # Leader should be in the first 10 lines of meaningful content
        self.assertLessEqual(
            leader_line, 10,
            f"vim.g.mapleader should be near the top (found on line {leader_line})"
        )


# ============================================================================
# Tests for .gitignore
# ============================================================================

class TestGitignore(unittest.TestCase):
    """Tests for .gitignore — repository ignore patterns."""

    def setUp(self):
        self.content = read_file(".gitignore")

    def test_file_exists(self):
        """.gitignore must exist at the repository root."""
        self.assertTrue(os.path.exists(os.path.join(REPO_ROOT, ".gitignore")))

    def test_lazy_lock_json_ignored(self):
        """lazy-lock.json must be ignored (key change in this PR)."""
        self.assertIn("lazy-lock.json", self.content)

    def test_luac_out_ignored(self):
        """luac.out (compiled Lua sources) must be ignored."""
        self.assertIn("luac.out", self.content)

    def test_src_rock_ignored(self):
        """*.src.rock (luarocks build files) must be ignored."""
        self.assertIn("*.src.rock", self.content)

    def test_zip_ignored(self):
        """*.zip files must be ignored."""
        self.assertIn("*.zip", self.content)

    def test_tar_gz_ignored(self):
        """*.tar.gz files must be ignored."""
        self.assertIn("*.tar.gz", self.content)

    def test_object_files_ignored(self):
        """Object files (*.o) must be ignored."""
        self.assertIn("*.o", self.content)

    def test_shared_libraries_ignored(self):
        """Shared object files (*.so) must be ignored."""
        self.assertIn("*.so", self.content)

    def test_executable_files_ignored(self):
        """Compiled executable files (*.exe, *.out) must be ignored."""
        self.assertIn("*.exe", self.content)
        self.assertIn("*.out", self.content)

    def test_dll_files_ignored(self):
        """Windows DLL files must be ignored."""
        self.assertIn("*.dll", self.content)

    def test_lazy_lock_before_luarocks_section(self):
        """
        lazy-lock.json must appear in the Lua compiled sources section,
        not in a random location.
        """
        lazy_lock_idx = self.content.find("lazy-lock.json")
        luarocks_idx = self.content.find("luarocks build files")
        # lazy-lock.json must appear before the luarocks section
        self.assertGreater(
            luarocks_idx, lazy_lock_idx,
            "lazy-lock.json should appear before the luarocks section"
        )

    def test_no_sensitive_files_pattern_missing(self):
        """Critical patterns must not have been accidentally removed."""
        # These were in the original .gitignore and must remain
        essential_patterns = ["*.o", "*.so", "*.dll", "*.exe"]
        for pattern in essential_patterns:
            self.assertIn(pattern, self.content,
                          f"Pattern '{pattern}' must not be removed from .gitignore")

    def test_lazy_lock_not_accidentally_tracked(self):
        """
        lazy-lock.json should not also be explicitly tracked via !lazy-lock.json.
        If it were negated, the ignore rule would be bypassed.
        """
        self.assertNotIn("!lazy-lock.json", self.content)


# ============================================================================
# Integration: init.lua modules actually exist
# ============================================================================

class TestInitLuaModulesExist(unittest.TestCase):
    """Verify that every module required by init.lua actually exists on disk."""

    REQUIRED_MODULES = [
        ("core.options",    "lua/core/options.lua"),
        ("core.autocmds",   "lua/core/autocmds.lua"),
        ("core.treesitter", "lua/core/treesitter.lua"),
        ("plugins",         "lua/plugins/init.lua"),
        ("core.keymaps",    "lua/core/keymaps.lua"),
    ]

    def test_all_required_modules_exist(self):
        """Every module required by init.lua must have a corresponding file."""
        for module_name, relative_path in self.REQUIRED_MODULES:
            full_path = os.path.join(REPO_ROOT, relative_path)
            self.assertTrue(
                os.path.exists(full_path),
                f"Module '{module_name}' required in init.lua but "
                f"'{relative_path}' does not exist"
            )

    def test_deleted_config_modules_gone(self):
        """Old config.* modules that were deleted must not exist."""
        deleted = [
            "lua/config/lazy.lua",
            "lua/config/options.lua",
        ]
        for path in deleted:
            full_path = os.path.join(REPO_ROOT, path)
            self.assertFalse(
                os.path.exists(full_path),
                f"Deleted module '{path}' should not exist — it was removed in this PR"
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)