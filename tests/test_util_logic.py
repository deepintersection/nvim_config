"""
Tests for lua/util/init.lua — Shared utility functions.

Since the utility module depends on the vim.* Neovim runtime API, we test
the *logic* of each function by reimplementing it in Python and verifying
it against its documented specification.  We also parse the Lua source to
confirm that the implementation matches the spec.

Functions under test:
  M.env(name)             — nil/empty → nil, non-empty → value
  M.env_bool(name, default) — "1"/"true"/"yes" → true, else → false/default
  M.env_exe(name)         — delegates to M.env
  M.is_ssh                — SSH_CLIENT or SSH_TTY env var presence
  M.is_windows / is_linux / is_mac — platform detection patterns

Source file: lua/util/init.lua
"""

import os
import re
import unittest


UTIL_PATH = os.path.join(
    os.path.dirname(__file__), "..", "lua", "util", "init.lua"
)


def read_util():
    with open(UTIL_PATH, encoding="utf-8") as fh:
        return fh.read()


# ============================================================================
# Python reimplementations of the Lua functions under test
# These mirror the logic in lua/util/init.lua so we can test them directly
# ============================================================================

def py_env(env_dict, name):
    """Python mirror of M.env(name)."""
    v = env_dict.get(name)
    if v is None or v == "":
        return None
    return v


def py_env_bool(env_dict, name, default=False):
    """Python mirror of M.env_bool(name, default)."""
    v = env_dict.get(name)
    if v is None or v == "":
        return default
    return v == "1" or v.lower() == "true" or v.lower() == "yes"


def py_is_ssh(env_dict):
    """Python mirror of M.is_ssh detection."""
    return (
        env_dict.get("SSH_CLIENT") is not None
        or env_dict.get("SSH_TTY") is not None
    )


# ============================================================================
# Tests for M.env()
# ============================================================================

class TestEnvFunction(unittest.TestCase):
    """Tests for M.env() — read env var, return nil for empty/unset."""

    def test_returns_value_when_set(self):
        """Returns the value when the variable is non-empty."""
        self.assertEqual(py_env({"FOO": "/usr/bin/foo"}, "FOO"), "/usr/bin/foo")

    def test_returns_none_when_unset(self):
        """Returns None when the variable is not in the environment."""
        self.assertIsNone(py_env({}, "FOO"))

    def test_returns_none_when_empty_string(self):
        """Returns None when the variable is set but empty."""
        self.assertIsNone(py_env({"FOO": ""}, "FOO"))

    def test_returns_value_with_spaces(self):
        """Values containing spaces are returned as-is."""
        self.assertEqual(py_env({"FOO": "/path with spaces/bin"}, "FOO"),
                         "/path with spaces/bin")

    def test_returns_value_with_special_chars(self):
        """Values with special characters are returned verbatim."""
        self.assertEqual(py_env({"FOO": "/opt/nvim-0.12.0"}, "FOO"),
                         "/opt/nvim-0.12.0")

    def test_multiple_vars_independent(self):
        """Multiple environment variables are retrieved independently."""
        env = {"A": "val_a", "B": "val_b", "C": ""}
        self.assertEqual(py_env(env, "A"), "val_a")
        self.assertEqual(py_env(env, "B"), "val_b")
        self.assertIsNone(py_env(env, "C"))
        self.assertIsNone(py_env(env, "D"))


# ============================================================================
# Tests for M.env_bool()
# ============================================================================

class TestEnvBoolFunction(unittest.TestCase):
    """Tests for M.env_bool() — parse boolean env vars."""

    # ---- truthy values ----

    def test_one_is_true(self):
        """'1' must be truthy."""
        self.assertTrue(py_env_bool({"FLAG": "1"}, "FLAG"))

    def test_true_lowercase_is_true(self):
        """'true' (lowercase) must be truthy."""
        self.assertTrue(py_env_bool({"FLAG": "true"}, "FLAG"))

    def test_true_uppercase_is_true(self):
        """'TRUE' (uppercase) must be truthy (case-insensitive)."""
        self.assertTrue(py_env_bool({"FLAG": "TRUE"}, "FLAG"))

    def test_true_mixed_case_is_true(self):
        """'True' (mixed case) must be truthy."""
        self.assertTrue(py_env_bool({"FLAG": "True"}, "FLAG"))

    def test_yes_lowercase_is_true(self):
        """'yes' (lowercase) must be truthy."""
        self.assertTrue(py_env_bool({"FLAG": "yes"}, "FLAG"))

    def test_yes_uppercase_is_true(self):
        """'YES' (uppercase) must be truthy."""
        self.assertTrue(py_env_bool({"FLAG": "YES"}, "FLAG"))

    def test_yes_mixed_case_is_true(self):
        """'Yes' (mixed case) must be truthy."""
        self.assertTrue(py_env_bool({"FLAG": "Yes"}, "FLAG"))

    # ---- falsy values ----

    def test_zero_is_false(self):
        """'0' must be falsy."""
        self.assertFalse(py_env_bool({"FLAG": "0"}, "FLAG"))

    def test_false_string_is_false(self):
        """'false' must be falsy."""
        self.assertFalse(py_env_bool({"FLAG": "false"}, "FLAG"))

    def test_no_string_is_false(self):
        """'no' must be falsy."""
        self.assertFalse(py_env_bool({"FLAG": "no"}, "FLAG"))

    def test_empty_string_returns_default(self):
        """Empty string returns the default value."""
        self.assertFalse(py_env_bool({"FLAG": ""}, "FLAG", default=False))
        self.assertTrue(py_env_bool({"FLAG": ""}, "FLAG", default=True))

    def test_unset_returns_default_false(self):
        """Unset var returns False when default is False."""
        self.assertFalse(py_env_bool({}, "FLAG", False))

    def test_unset_returns_default_true(self):
        """Unset var returns True when default is True."""
        self.assertTrue(py_env_bool({}, "FLAG", True))

    def test_unset_returns_false_by_default(self):
        """Without an explicit default, unset var returns False."""
        self.assertFalse(py_env_bool({}, "FLAG"))

    def test_random_string_is_false(self):
        """An arbitrary non-boolean string must be falsy."""
        self.assertFalse(py_env_bool({"FLAG": "maybe"}, "FLAG"))
        self.assertFalse(py_env_bool({"FLAG": "enabled"}, "FLAG"))
        self.assertFalse(py_env_bool({"FLAG": "on"}, "FLAG"))

    def test_whitespace_only_returns_default(self):
        """Whitespace-only value is NOT truthy (not '1'/'true'/'yes')."""
        # Note: " " is not "1", "true", or "yes" — returns False
        self.assertFalse(py_env_bool({"FLAG": " "}, "FLAG"))

    # ---- boundary / regression ----

    def test_nvim_format_on_save_pattern(self):
        """NVIM_FORMAT_ON_SAVE=1 enables format on save."""
        self.assertTrue(py_env_bool({"NVIM_FORMAT_ON_SAVE": "1"}, "NVIM_FORMAT_ON_SAVE"))

    def test_nvim_clipboard_pattern(self):
        """NVIM_CLIPBOARD=1 enables clipboard integration."""
        self.assertTrue(py_env_bool({"NVIM_CLIPBOARD": "1"}, "NVIM_CLIPBOARD"))

    def test_nvim_clipboard_unset(self):
        """Without NVIM_CLIPBOARD, clipboard remains disabled."""
        self.assertFalse(py_env_bool({}, "NVIM_CLIPBOARD"))

    def test_nvim_ghost_text_default_off(self):
        """NVIM_GHOST_TEXT defaults to False when not set."""
        self.assertFalse(py_env_bool({}, "NVIM_GHOST_TEXT", False))

    def test_nvim_ghost_text_enabled(self):
        """NVIM_GHOST_TEXT=1 enables ghost text."""
        self.assertTrue(py_env_bool({"NVIM_GHOST_TEXT": "1"}, "NVIM_GHOST_TEXT"))


# ============================================================================
# Tests for M.is_ssh (env-based detection)
# ============================================================================

class TestSshDetection(unittest.TestCase):
    """Tests for M.is_ssh — SSH session detection via env vars."""

    def test_ssh_client_set_means_ssh(self):
        """SSH_CLIENT being set means we are in an SSH session."""
        self.assertTrue(py_is_ssh({"SSH_CLIENT": "1.2.3.4 12345 22"}))

    def test_ssh_tty_set_means_ssh(self):
        """SSH_TTY being set means we are in an SSH session."""
        self.assertTrue(py_is_ssh({"SSH_TTY": "/dev/pts/0"}))

    def test_both_ssh_vars_set_means_ssh(self):
        """Both vars set still means SSH."""
        self.assertTrue(py_is_ssh({
            "SSH_CLIENT": "1.2.3.4 12345 22",
            "SSH_TTY": "/dev/pts/0"
        }))

    def test_neither_set_means_not_ssh(self):
        """No SSH vars means local session."""
        self.assertFalse(py_is_ssh({}))

    def test_unrelated_vars_do_not_trigger_ssh(self):
        """Unrelated environment variables must not trigger SSH detection."""
        self.assertFalse(py_is_ssh({
            "TERM": "xterm-256color",
            "HOME": "/home/user",
            "DISPLAY": ":0",
        }))


# ============================================================================
# Source code structure tests
# ============================================================================

class TestUtilSourceStructure(unittest.TestCase):
    """Verify lua/util/init.lua source structure and function signatures."""

    def setUp(self):
        self.content = read_util()

    def test_file_exists(self):
        """lua/util/init.lua must exist."""
        self.assertTrue(os.path.exists(UTIL_PATH))

    def test_module_table_declared(self):
        """Must declare a module table `M`."""
        self.assertIn("local M = {}", self.content)

    def test_module_returned(self):
        """Must return the module table at end."""
        self.assertIn("return M", self.content)

    def test_env_function_defined(self):
        """M.env function must be defined."""
        self.assertIn("function M.env(", self.content)

    def test_env_bool_function_defined(self):
        """M.env_bool function must be defined."""
        self.assertIn("function M.env_bool(", self.content)

    def test_env_exe_function_defined(self):
        """M.env_exe function must be defined."""
        self.assertIn("function M.env_exe(", self.content)

    def test_lsp_attached_function_defined(self):
        """M.lsp_attached function must be defined."""
        self.assertIn("function M.lsp_attached(", self.content)

    def test_lsp_get_client_function_defined(self):
        """M.lsp_get_client function must be defined."""
        self.assertIn("function M.lsp_get_client(", self.content)

    def test_ts_get_parser_function_defined(self):
        """M.ts_get_parser function must be defined."""
        self.assertIn("function M.ts_get_parser(", self.content)

    def test_lsp_map_function_defined(self):
        """M.lsp_map function must be defined."""
        self.assertIn("function M.lsp_map(", self.content)

    def test_file_exists_function_defined(self):
        """M.file_exists function must be defined."""
        self.assertIn("function M.file_exists(", self.content)

    def test_is_dir_function_defined(self):
        """M.is_dir function must be defined."""
        self.assertIn("function M.is_dir(", self.content)

    def test_is_ssh_field_declared(self):
        """M.is_ssh must be declared as a module field."""
        self.assertIn("M.is_ssh", self.content)

    def test_is_ssh_checks_ssh_client(self):
        """is_ssh must check SSH_CLIENT environment variable."""
        self.assertIn("SSH_CLIENT", self.content)

    def test_is_ssh_checks_ssh_tty(self):
        """is_ssh must check SSH_TTY environment variable."""
        self.assertIn("SSH_TTY", self.content)

    def test_env_function_handles_empty_string(self):
        """M.env must treat empty string the same as nil."""
        # The pattern `v == nil or v == ""` must appear
        self.assertIn('v == ""', self.content)

    def test_env_bool_checks_truthy_values(self):
        """M.env_bool must explicitly check for '1', 'true', and 'yes'."""
        self.assertIn('"1"', self.content)
        self.assertIn('"true"', self.content)
        self.assertIn('"yes"', self.content)

    def test_env_bool_uses_lower_for_case_insensitive(self):
        """M.env_bool must use :lower() for case-insensitive comparison."""
        self.assertIn(":lower()", self.content)

    def test_ts_get_parser_uses_pcall(self):
        """ts_get_parser must use pcall to safely call vim.treesitter.get_parser."""
        self.assertIn("pcall", self.content)
        self.assertIn("vim.treesitter.get_parser", self.content)

    def test_file_exists_uses_fs_stat(self):
        """M.file_exists must use vim.uv.fs_stat."""
        self.assertIn("vim.uv.fs_stat", self.content)

    def test_env_exe_delegates_to_env(self):
        """M.env_exe must delegate to M.env."""
        self.assertIn("M.env(", self.content)
        # env_exe function should call M.env internally
        m = re.search(r'function M\.env_exe\(.*?\)\s*(.*?)end',
                      self.content, re.DOTALL)
        self.assertIsNotNone(m)
        self.assertIn("M.env(", m.group(1))

    def test_type_annotations_present(self):
        """Key functions should have LuaDoc type annotations."""
        # Check for at least one @param annotation
        self.assertIn("---@param", self.content)
        # Check for at least one @return annotation
        self.assertIn("---@return", self.content)

    def test_is_windows_field(self):
        """M.is_windows must be declared."""
        self.assertIn("M.is_windows", self.content)

    def test_is_linux_field(self):
        """M.is_linux must be declared."""
        self.assertIn("M.is_linux", self.content)

    def test_is_mac_field(self):
        """M.is_mac must be declared."""
        self.assertIn("M.is_mac", self.content)


# ============================================================================
# Logic tests for env_bool truth table — exhaustive boundary coverage
# ============================================================================

class TestEnvBoolTruthTable(unittest.TestCase):
    """Exhaustive truth table tests for M.env_bool."""

    TRUTHY = ["1", "true", "TRUE", "True", "TrUe", "yes", "YES", "Yes", "YeS"]
    FALSY = ["0", "false", "FALSE", "no", "NO", "off", "OFF", "2", "11",
             "nope", "enabled", "y", "t", "ok", "1.0", "yes ", " yes"]

    def test_all_truthy_values(self):
        """All documented truthy string values must return True."""
        for val in self.TRUTHY:
            with self.subTest(val=val):
                result = py_env_bool({"X": val}, "X")
                self.assertTrue(result,
                                f"Expected True for env_bool with value '{val}'")

    def test_all_falsy_values(self):
        """All non-truthy string values must return False."""
        for val in self.FALSY:
            with self.subTest(val=val):
                result = py_env_bool({"X": val}, "X")
                self.assertFalse(result,
                                 f"Expected False for env_bool with value '{val}'")


if __name__ == "__main__":
    unittest.main(verbosity=2)
