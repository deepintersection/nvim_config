"""
Tests for lua/plugins/*.lua — Plugin specification files.

Files under test:
  lua/plugins/init.lua       — lazy.nvim bootstrap and plugin manifest
  lua/plugins/completion.lua — blink.cmp completion configuration
  lua/plugins/editor.lua     — conform, nvim-lint, fzf-lua, oil.nvim
  lua/plugins/git.lua        — gitsigns, fugitive, diffview
  lua/plugins/fm/oil.lua     — minimal oil.nvim spec (legacy/minimal)

Tests verify plugin names, configuration structure, keymap registrations,
environment variable handling patterns, and required settings.
"""

import os
import re
import unittest

PLUGINS_DIR = os.path.join(os.path.dirname(__file__), "..", "lua", "plugins")
REPO_ROOT = os.path.join(os.path.dirname(__file__), "..")


def read_plugin(path):
    """Return the contents of a plugin file (absolute or relative to plugins/)."""
    if os.path.isabs(path):
        full_path = path
    else:
        full_path = os.path.join(PLUGINS_DIR, path)
    with open(full_path, encoding="utf-8") as fh:
        return fh.read()


# ============================================================================
# Tests for lua/plugins/init.lua
# ============================================================================

class TestPluginsInit(unittest.TestCase):
    """Tests for lua/plugins/init.lua — lazy.nvim bootstrap."""

    def setUp(self):
        self.content = read_plugin("init.lua")

    def test_file_exists(self):
        """lua/plugins/init.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(PLUGINS_DIR, "init.lua")))

    def test_lazy_path_from_stdpath(self):
        """lazy.nvim path must be derived from vim.fn.stdpath('data')."""
        self.assertIn('stdpath("data")', self.content)
        self.assertIn("lazy/lazy.nvim", self.content)

    def test_bootstrap_clones_lazy_if_missing(self):
        """lazy.nvim must be cloned if not present (bootstrap guard)."""
        self.assertIn("fs_stat", self.content)
        self.assertIn("git", self.content)
        self.assertIn("clone", self.content)

    def test_stable_branch_used(self):
        """lazy.nvim must be cloned from the stable branch."""
        self.assertIn('"--branch=stable"', self.content)

    def test_rtp_prepend(self):
        """lazy.nvim path must be prepended to runtimepath."""
        self.assertIn("rtp:prepend", self.content)

    def test_lazy_setup_called(self):
        """require('lazy').setup() must be called."""
        self.assertIn('require("lazy").setup', self.content)

    def test_all_plugin_modules_imported(self):
        """All plugin sub-modules must be imported via { import = ... }."""
        expected_imports = [
            "plugins.treesitter",
            "plugins.lsp",
            "plugins.editor",
            "plugins.ui",
            "plugins.completion",
            "plugins.git",
        ]
        for module in expected_imports:
            self.assertIn(f'"{module}"', self.content,
                          f"Plugin module '{module}' not imported")

    def test_lazy_defaults_lazy_true(self):
        """Plugins must be lazy by default."""
        self.assertIn("lazy = true", self.content)

    def test_checker_disabled(self):
        """Automatic update checker must be disabled (noisy over SSH)."""
        self.assertIn("checker", self.content)
        self.assertIn("enabled = false", self.content)

    def test_lock_file_location(self):
        """lazy-lock.json must be stored in the config directory."""
        self.assertIn("lockfile", self.content)
        self.assertIn("lazy-lock.json", self.content)
        self.assertIn('stdpath("config")', self.content)

    def test_ui_border_rounded(self):
        """lazy.nvim UI must use rounded borders."""
        self.assertIn('border = "rounded"', self.content)

    def test_disabled_plugins_list(self):
        """Built-in plugins we don't need must be disabled for startup speed."""
        self.assertIn("disabled_plugins", self.content)
        self.assertIn('"gzip"', self.content)
        self.assertIn('"netrwPlugin"', self.content)

    def test_fallback_colorscheme_configured(self):
        """A fallback colorscheme must be configured for plugin install."""
        self.assertIn("colorscheme", self.content)
        self.assertIn('"habamax"', self.content)

    def test_error_handling_on_clone_failure(self):
        """Bootstrap must handle git clone failure gracefully."""
        self.assertIn("shell_error", self.content)
        # Should notify or handle the error
        self.assertTrue(
            "vim.notify" in self.content or "nvim_echo" in self.content,
            "Clone failure must be reported to the user"
        )

    def test_change_detection_notify_false(self):
        """Config change detection must not notify (avoid noise)."""
        self.assertIn("change_detection", self.content)
        self.assertIn("notify  = false", self.content)


# ============================================================================
# Tests for lua/plugins/completion.lua
# ============================================================================

class TestCompletionPlugin(unittest.TestCase):
    """Tests for lua/plugins/completion.lua — blink.cmp v2 configuration."""

    def setUp(self):
        self.content = read_plugin("completion.lua")

    def test_file_exists(self):
        """lua/plugins/completion.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(PLUGINS_DIR, "completion.lua")))

    def test_blink_cmp_plugin_defined(self):
        """blink.cmp plugin must be configured."""
        self.assertIn("saghen/blink.cmp", self.content)

    def test_blink_lib_dependency(self):
        """blink.lib must be declared as a required dependency."""
        self.assertIn("saghen/blink.lib", self.content)

    def test_build_from_source(self):
        """blink.cmp must be built from source with cargo."""
        self.assertIn("cargo build --release", self.content)

    def test_main_branch(self):
        """blink.cmp must use the main branch (v2 is on main)."""
        self.assertIn('branch = "main"', self.content)

    def test_insert_enter_trigger(self):
        """Completion must be triggered on InsertEnter."""
        self.assertIn('"InsertEnter"', self.content)

    def test_cmdline_enter_trigger(self):
        """Completion must also trigger on CmdlineEnter."""
        self.assertIn('"CmdlineEnter"', self.content)

    def test_enabled_function_present(self):
        """An enabled() function must gate completion in special buffers."""
        self.assertIn("enabled = function()", self.content)

    def test_completion_disabled_in_diff_mode(self):
        """Completion must be disabled in diff mode."""
        self.assertIn("vim.wo.diff", self.content)
        self.assertIn("return false", self.content)

    def test_completion_disabled_for_fugitive(self):
        """Completion must be disabled in fugitive buffers."""
        self.assertIn('"fugitive"', self.content)

    def test_keymap_preset_none(self):
        """Keymap preset must be 'none' (all keymaps are explicit)."""
        self.assertIn('preset = "none"', self.content)

    def test_ctrl_space_shows_completion(self):
        """Ctrl-Space must show the completion menu."""
        self.assertIn('"<C-Space>"', self.content)
        self.assertIn('"show"', self.content)

    def test_ctrl_e_hides_completion(self):
        """Ctrl-E must hide/cancel completion."""
        self.assertIn('"<C-e>"', self.content)
        self.assertIn('"hide"', self.content)

    def test_tab_selects_next(self):
        """Tab must select the next completion item."""
        self.assertIn('"<Tab>"', self.content)
        self.assertIn('"select_next"', self.content)

    def test_enter_accepts(self):
        """Enter must accept the selected completion item."""
        self.assertIn('"<CR>"', self.content)
        self.assertIn('"accept"', self.content)

    def test_not_remapping_ctrl_s(self):
        """<C-S> must NOT be remapped (it's 0.12 signature help)."""
        # Ctrl-S should not appear as a blink keymap
        keymap_section = re.search(r'keymap\s*=\s*\{(.*?)\}', self.content, re.DOTALL)
        if keymap_section:
            # Check that C-S doesn't appear in the keymap table
            self.assertNotIn('"<C-S>"', keymap_section.group(1))

    def test_not_remapping_ctrl_r(self):
        """<C-R> must NOT be remapped (0.12 literal register insert)."""
        self.assertNotIn('"<C-R>"', self.content)

    def test_menu_border_rounded(self):
        """Completion menu must use rounded borders."""
        self.assertIn('border      = "rounded"', self.content)

    def test_documentation_auto_show(self):
        """Documentation popup must auto-show."""
        self.assertIn("auto_show          = true", self.content)

    def test_ghost_text_ssh_aware(self):
        """Ghost text must be disabled by default (SSH performance)."""
        self.assertIn("ghost_text", self.content)
        self.assertIn("NVIM_GHOST_TEXT", self.content)

    def test_sources_lsp_present(self):
        """LSP must be a default completion source."""
        self.assertIn('"lsp"', self.content)
        self.assertIn("sources", self.content)

    def test_sources_path_present(self):
        """Path must be a default completion source."""
        self.assertIn('"path"', self.content)

    def test_sources_buffer_present(self):
        """Buffer must be a default completion source."""
        self.assertIn('"buffer"', self.content)

    def test_sources_snippets_present(self):
        """Snippets must be a default completion source."""
        self.assertIn('"snippets"', self.content)

    def test_lazydev_source_for_lua(self):
        """LazyDev source must be enabled for Lua files."""
        self.assertIn('"lazydev"', self.content)
        self.assertIn("lua", self.content)
        self.assertIn("lazydev.integrations.blink", self.content)

    def test_lazydev_score_offset(self):
        """LazyDev source must have high score offset to beat LSP for Lua API."""
        m = re.search(r'score_offset\s*=\s*(\d+)', self.content)
        self.assertIsNotNone(m)
        self.assertGreaterEqual(int(m.group(1)), 100,
                                "lazydev score_offset must be high enough to beat LSP")

    def test_fuzzy_uses_rust(self):
        """Fuzzy matching must prefer the Rust implementation for performance."""
        self.assertIn('"prefer_rust"', self.content)

    def test_frecency_enabled(self):
        """Frecency-based ranking must be enabled."""
        self.assertIn("frecency", self.content)
        self.assertIn("enabled = true", self.content)

    def test_cmdline_completion_enabled(self):
        """Cmdline completion must be enabled."""
        self.assertIn("cmdline", self.content)
        self.assertIn("enabled = true", self.content)

    def test_autocomplete_disabled(self):
        """0.12 built-in autocomplete must be explicitly disabled."""
        self.assertIn("vim.opt.autocomplete = false", self.content)

    def test_lsp_capabilities_merged(self):
        """blink.cmp LSP capabilities must be merged with global config."""
        self.assertIn("get_lsp_capabilities", self.content)
        self.assertIn('vim.lsp.config("*"', self.content)

    def test_ghost_text_toggle_keymap(self):
        """A keymap for toggling ghost text must be registered."""
        self.assertIn('"<leader>ug"', self.content)

    def test_text_kind_filtered_from_lsp(self):
        """Text-kind LSP completions must be filtered out (too noisy)."""
        self.assertIn("transform_items", self.content)
        self.assertIn("CompletionItemKind", self.content)
        self.assertIn("kinds.Text", self.content)

    def test_buffer_source_only_normal_buffers(self):
        """Buffer source must only scan normal buftype buffers."""
        self.assertIn('buftype == ""', self.content)
        self.assertIn("get_bufnrs", self.content)

    def test_signature_help_enabled(self):
        """Signature help must be enabled."""
        self.assertIn("signature", self.content)
        self.assertIn("enabled = true", self.content)

    def test_util_required(self):
        """util module must be required for SSH detection."""
        self.assertIn('require("util")', self.content)

    def test_ssh_aware_documentation_delay(self):
        """Documentation delay must be longer when over SSH."""
        self.assertIn("is_ssh", self.content)
        self.assertIn("auto_show_delay_ms", self.content)


# ============================================================================
# Tests for lua/plugins/editor.lua
# ============================================================================

class TestEditorPlugin(unittest.TestCase):
    """Tests for lua/plugins/editor.lua — conform, lint, fzf-lua, oil.nvim."""

    def setUp(self):
        self.content = read_plugin("editor.lua")

    def test_file_exists(self):
        """lua/plugins/editor.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(PLUGINS_DIR, "editor.lua")))

    def test_conform_plugin_defined(self):
        """conform.nvim must be configured."""
        self.assertIn("stevearc/conform.nvim", self.content)

    def test_nvim_lint_plugin_defined(self):
        """nvim-lint must be configured."""
        self.assertIn("mfussenegger/nvim-lint", self.content)

    def test_fzf_lua_plugin_defined(self):
        """fzf-lua must be configured."""
        self.assertIn("ibhagwan/fzf-lua", self.content)

    def test_oil_nvim_plugin_defined(self):
        """oil.nvim must be configured."""
        self.assertIn("stevearc/oil.nvim", self.content)

    def test_util_required(self):
        """util module must be required."""
        self.assertIn('require("util")', self.content)

    # ---- conform.nvim tests ----

    def test_ruff_format_for_python(self):
        """Python formatting must use ruff_format when NVIM_RUFF_PATH is set."""
        self.assertIn("ruff_format", self.content)
        self.assertIn("NVIM_RUFF_PATH", self.content)

    def test_black_fallback_for_python(self):
        """Black must be a fallback Python formatter."""
        self.assertIn("NVIM_BLACK_PATH", self.content)
        self.assertIn('"black"', self.content)

    def test_stylua_for_lua(self):
        """Lua formatting must use stylua."""
        self.assertIn("NVIM_STYLUA_PATH", self.content)
        self.assertIn('"stylua"', self.content)

    def test_rustfmt_for_rust(self):
        """Rust formatting must use rustfmt."""
        self.assertIn("NVIM_RUSTFMT_PATH", self.content)
        self.assertIn('"rustfmt"', self.content)

    def test_clang_format_for_c(self):
        """C/C++ formatting must use clang-format."""
        self.assertIn("NVIM_CLANG_FORMAT_PATH", self.content)
        self.assertIn("clang_format", self.content)

    def test_shfmt_for_shell(self):
        """Shell formatting must use shfmt."""
        self.assertIn("NVIM_SHFMT_PATH", self.content)
        self.assertIn('"shfmt"', self.content)

    def test_prettier_for_web_formats(self):
        """JSON/YAML/Markdown/HTML/CSS formatting must use prettier."""
        self.assertIn("NVIM_PRETTIER_PATH", self.content)
        self.assertIn('"prettier"', self.content)

    def test_taplo_for_toml(self):
        """TOML formatting must use taplo."""
        self.assertIn("NVIM_TAPLO_PATH", self.content)
        self.assertIn('"taplo"', self.content)

    def test_format_on_save_opt_in(self):
        """Format on save must be opt-in via NVIM_FORMAT_ON_SAVE=1."""
        self.assertIn("NVIM_FORMAT_ON_SAVE", self.content)
        self.assertIn("format_on_save", self.content)

    def test_format_keymap_leader_cf(self):
        """<leader>cf must trigger formatting."""
        self.assertIn('"<leader>cf"', self.content)

    def test_format_toggle_leader_cf_caps(self):
        """<leader>cF must toggle format-on-save for the buffer."""
        self.assertIn('"<leader>cF"', self.content)

    def test_format_user_command(self):
        """A :Format user command must be registered."""
        self.assertIn('"Format"', self.content)
        self.assertIn("create_user_command", self.content)

    def test_shfmt_4_space_indent(self):
        """shfmt must be configured with 4-space indentation."""
        self.assertIn('"-i", "4"', self.content)

    def test_conform_lsp_fallback(self):
        """conform must fall back to LSP formatting when no formatter is configured."""
        self.assertIn('lsp_format  = "fallback"', self.content)

    # ---- nvim-lint tests ----

    def test_shellcheck_for_bash(self):
        """shellcheck must be used for bash/sh linting."""
        self.assertIn("NVIM_SHELLCHECK_PATH", self.content)
        self.assertIn('"shellcheck"', self.content)

    def test_hadolint_for_dockerfile(self):
        """hadolint must be used for Dockerfile linting."""
        self.assertIn("NVIM_HADOLINT_PATH", self.content)
        self.assertIn('"hadolint"', self.content)

    def test_lint_autocmd_on_write(self):
        """Linting must trigger on buffer write."""
        self.assertIn('"BufWritePost"', self.content)

    def test_lint_manual_trigger_keymap(self):
        """<leader>ll must manually trigger linting."""
        self.assertIn('"<leader>ll"', self.content)
        self.assertIn("try_lint", self.content)

    def test_lint_only_runs_for_assigned_filetypes(self):
        """Linting must only run when a linter is assigned to the filetype."""
        self.assertIn("linters_by_ft", self.content)
        self.assertIn("linters_by_ft[ft]", self.content)

    # ---- fzf-lua tests ----

    def test_fzf_lua_mini_icons_dep(self):
        """fzf-lua must depend on mini.icons."""
        self.assertIn("echasnovski/mini.icons", self.content)

    def test_fzf_path_from_env(self):
        """fzf binary path must be configurable via NVIM_FZF_PATH."""
        self.assertIn("NVIM_FZF_PATH", self.content)
        self.assertIn("fzf_bin", self.content)

    def test_fzf_ssh_aware_layout(self):
        """fzf-lua preview layout must adapt for SSH sessions."""
        self.assertIn("is_ssh", self.content)
        self.assertIn('"vertical"', self.content)
        self.assertIn('"horizontal"', self.content)

    def test_fzf_find_files_keymap(self):
        """<leader>ff must open file finder."""
        self.assertIn('"<leader>ff"', self.content)

    def test_fzf_live_grep_keymap(self):
        """<leader>fg must open live grep."""
        self.assertIn('"<leader>fg"', self.content)

    def test_fzf_buffers_keymap(self):
        """<leader>fb must open buffer list."""
        self.assertIn('"<leader>fb"', self.content)

    def test_fzf_help_tags_keymap(self):
        """<leader>fh must open help tag search."""
        self.assertIn('"<leader>fh"', self.content)

    def test_fzf_document_symbols_keymap(self):
        """<leader>fs must open LSP document symbols."""
        self.assertIn('"<leader>fs"', self.content)
        self.assertIn("lsp_document_symbols", self.content)

    def test_fzf_diagnostics_keymap(self):
        """<leader>fd must open diagnostic list."""
        self.assertIn('"<leader>fd"', self.content)
        self.assertIn("diagnostics", self.content)

    def test_fzf_uses_ripgrep(self):
        """fzf grep must use ripgrep."""
        self.assertIn("rg --files", self.content)

    def test_fzf_respects_gitignore(self):
        """fzf file search must respect .gitignore."""
        self.assertIn("!.git", self.content)

    def test_fzf_ui_select_registered(self):
        """fzf-lua must register as vim.ui.select provider."""
        self.assertIn("register_ui_select", self.content)

    def test_fzf_ctrl_q_to_quickfix(self):
        """Ctrl-Q inside fzf must send results to quickfix."""
        self.assertIn('"ctrl-q"', self.content)

    # ---- oil.nvim tests ----

    def test_oil_default_file_explorer(self):
        """oil.nvim must be set as the default file explorer."""
        self.assertIn("default_file_explorer = true", self.content)

    def test_oil_key_minus_opens_parent(self):
        """'-' key must open oil in the parent directory."""
        self.assertIn('"-"', self.content)
        self.assertIn('"<cmd>Oil<CR>"', self.content)

    def test_oil_leader_fe_keymap(self):
        """<leader>fe must open oil."""
        self.assertIn('"<leader>fe"', self.content)

    def test_oil_ssh_aware_watch(self):
        """oil.nvim file watching must be disabled over SSH."""
        self.assertIn("watch_for_changes", self.content)
        self.assertIn("is_ssh", self.content)

    def test_oil_rounded_borders(self):
        """oil.nvim float/preview must use rounded borders."""
        self.assertIn('border      = "rounded"', self.content)

    def test_oil_no_winblend(self):
        """oil.nvim must not use window transparency (SSH compatibility)."""
        self.assertIn("winblend = 0", self.content)

    def test_oil_natural_sort(self):
        """oil.nvim must use natural sort order."""
        self.assertIn("natural_order = true", self.content)

    def test_oil_show_hidden_false_by_default(self):
        """oil.nvim must not show hidden files by default."""
        self.assertIn("show_hidden = false", self.content)


# ============================================================================
# Tests for lua/plugins/git.lua
# ============================================================================

class TestGitPlugin(unittest.TestCase):
    """Tests for lua/plugins/git.lua — Git integration plugins."""

    def setUp(self):
        self.content = read_plugin("git.lua")

    def test_file_exists(self):
        """lua/plugins/git.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(PLUGINS_DIR, "git.lua")))

    def test_gitsigns_plugin_defined(self):
        """gitsigns.nvim must be configured."""
        self.assertIn("lewis6991/gitsigns.nvim", self.content)

    def test_gitsigns_on_buf_events(self):
        """gitsigns must load on buffer read/write events."""
        self.assertIn('"BufReadPost"', self.content)
        self.assertIn('"BufNewFile"', self.content)

    def test_gitsigns_sign_column_enabled(self):
        """gitsigns must show signs in the sign column."""
        self.assertIn("signcolumn = true", self.content)

    def test_gitsigns_signs_defined(self):
        """gitsigns must have signs configured for add/change/delete."""
        self.assertIn("add", self.content)
        self.assertIn("change", self.content)
        self.assertIn("delete", self.content)

    def test_gitsigns_staged_signs_enabled(self):
        """gitsigns must show staged hunk signs."""
        self.assertIn("signs_staged_enable = true", self.content)


# ============================================================================
# Tests for lua/plugins/fm/oil.lua (minimal oil spec)
# ============================================================================

class TestFmOilPlugin(unittest.TestCase):
    """Tests for lua/plugins/fm/oil.lua — minimal oil.nvim specification."""

    def setUp(self):
        path = os.path.join(PLUGINS_DIR, "fm", "oil.lua")
        with open(path, encoding="utf-8") as fh:
            self.content = fh.read()

    def test_file_exists(self):
        """lua/plugins/fm/oil.lua must exist."""
        self.assertTrue(
            os.path.exists(os.path.join(PLUGINS_DIR, "fm", "oil.lua"))
        )

    def test_oil_plugin_name(self):
        """Plugin name must be 'stevearc/oil.nvim'."""
        self.assertIn("stevearc/oil.nvim", self.content)

    def test_returns_table(self):
        """File must return a plugin spec table."""
        self.assertTrue(
            self.content.strip().startswith("return"),
            "fm/oil.lua must start with 'return'"
        )

    def test_has_opts(self):
        """opts key must be present."""
        self.assertIn("opts", self.content)

    def test_lazy_false(self):
        """oil.nvim must not be lazy-loaded (recommended by plugin author)."""
        self.assertIn("lazy = false", self.content)

    def test_has_dependencies(self):
        """Dependencies must be declared."""
        self.assertIn("dependencies", self.content)

    def test_type_annotation(self):
        """Type annotation for opts must be present."""
        self.assertIn("---@type oil.SetupOpts", self.content)


# ============================================================================
# Cross-plugin consistency tests
# ============================================================================

class TestPluginConsistency(unittest.TestCase):
    """Cross-file consistency checks for the plugin configuration."""

    def _read(self, fname):
        return read_plugin(fname)

    def test_all_plugin_files_exist(self):
        """All expected plugin files must exist."""
        expected = [
            "init.lua",
            "completion.lua",
            "editor.lua",
            "git.lua",
            "lsp.lua",
        ]
        for fname in expected:
            path = os.path.join(PLUGINS_DIR, fname)
            self.assertTrue(os.path.exists(path),
                            f"Missing plugin file: lua/plugins/{fname}")

    def test_fm_directory_exists(self):
        """lua/plugins/fm/ directory must exist."""
        fm_dir = os.path.join(PLUGINS_DIR, "fm")
        self.assertTrue(os.path.isdir(fm_dir),
                        "lua/plugins/fm/ directory must exist")

    def test_editor_uses_util_env_for_formatters(self):
        """editor.lua must use util.env() to check formatter availability."""
        content = self._read("editor.lua")
        self.assertIn("util.env(", content)
        self.assertIn('util.env("NVIM_RUFF_PATH")', content)

    def test_completion_uses_util_is_ssh(self):
        """completion.lua must use util.is_ssh for SSH-aware behaviour."""
        content = self._read("completion.lua")
        self.assertIn("util.is_ssh", content)

    def test_editor_uses_util_is_ssh(self):
        """editor.lua must use util.is_ssh for SSH-aware behaviour."""
        content = self._read("editor.lua")
        self.assertIn("util.is_ssh", content)

    def test_leader_groups_consistent(self):
        """
        Leader group comments must be consistent across keymap-defining files.
        <leader>f is documented as 'find/files' and fzf-lua uses it.
        """
        editor_content = self._read("editor.lua")
        # fzf-lua uses <leader>f group
        self.assertIn('"<leader>ff"', editor_content)
        self.assertIn('"<leader>fg"', editor_content)

    def test_netrw_disabled_not_used_as_plugin(self):
        """
        netrw must not be registered as a plugin dependency or enabled.
        It is acceptable to reference netrw in comments (explaining oil.nvim replaces it)
        or in the disabled_plugins list.
        """
        init_content = self._read("init.lua")
        # netrwPlugin must be in the disabled list (confirmed it is)
        self.assertIn('"netrwPlugin"', init_content)

        editor_content = self._read("editor.lua")
        # netrw must not be required or loaded as a plugin in editor.lua
        self.assertNotIn('require("netrw")', editor_content)
        self.assertNotIn('"netrw"', editor_content.split("--")[0])  # not before first comment

    def test_git_plugin_returns_table(self):
        """git.lua must return a table of plugin specs."""
        content = self._read("git.lua")
        self.assertIn("return {", content)


if __name__ == "__main__":
    unittest.main(verbosity=2)