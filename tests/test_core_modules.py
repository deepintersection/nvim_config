"""
Tests for lua/core/*.lua — Core Neovim configuration modules.

Files under test:
  lua/core/autocmds.lua   — Global autocommands
  lua/core/options.lua    — Neovim option settings
  lua/core/keymaps.lua    — Global key mappings
  lua/core/treesitter.lua — Native treesitter highlighting setup

Tests verify structural requirements, expected autocmd events, option values,
keymap registrations, and conditional logic patterns.
"""

import os
import re
import unittest

CORE_DIR = os.path.join(os.path.dirname(__file__), "..", "lua", "core")


def read_core(filename):
    """Return the contents of lua/core/<filename>."""
    path = os.path.join(CORE_DIR, filename)
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def find_autocmds(content):
    """Return a list of autocmd event names found in content."""
    return re.findall(r'nvim_create_autocmd\(\s*[{"]([^}"]+)["}]', content)


def find_augroup_names(content):
    """Return a list of augroup names passed to the local augroup() helper."""
    return re.findall(r'augroup\("([^"]+)"\)', content)


# ============================================================================
# Tests for lua/core/autocmds.lua
# ============================================================================

class TestAutocmdsStructure(unittest.TestCase):
    """Tests for lua/core/autocmds.lua — structural requirements."""

    def setUp(self):
        self.content = read_core("autocmds.lua")

    def test_file_exists(self):
        """lua/core/autocmds.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(CORE_DIR, "autocmds.lua")))

    def test_augroup_helper_defined(self):
        """A local augroup() helper function must be defined."""
        self.assertIn("local function augroup(name)", self.content)

    def test_augroup_uses_config_prefix(self):
        """Augroup names must be prefixed with 'config_' to avoid collisions."""
        self.assertIn('"config_" .. name', self.content)

    def test_augroup_clears_on_create(self):
        """Augroups must use { clear = true } to prevent duplicate autocmds."""
        self.assertIn("clear = true", self.content)

    def test_text_yank_post_autocmd(self):
        """TextYankPost autocmd must be registered for yank highlighting."""
        self.assertIn('"TextYankPost"', self.content)

    def test_yank_uses_visual_highlight(self):
        """Yank highlight must use 'Visual' highlight group."""
        self.assertIn('"Visual"', self.content)
        self.assertIn("timeout = 150", self.content)

    def test_vim_resized_autocmd(self):
        """VimResized autocmd must be registered for split resizing."""
        self.assertIn('"VimResized"', self.content)

    def test_resize_uses_tabdo(self):
        """VimResized handler must equalise all windows across all tabs."""
        self.assertIn("tabdo wincmd =", self.content)

    def test_buf_read_post_autocmd(self):
        """BufReadPost autocmd must be registered to restore cursor position."""
        self.assertIn('"BufReadPost"', self.content)

    def test_restore_cursor_uses_mark(self):
        """Cursor restore must read the '\"' mark."""
        self.assertIn('nvim_buf_get_mark', self.content)
        # The mark name is the double-quote character, passed as '"' in Lua
        self.assertIn("'\"'", self.content)

    def test_restore_cursor_bounds_check(self):
        """Cursor restore must check that mark line is within buffer bounds."""
        self.assertIn("line_count", self.content)
        self.assertIn("mark[1] > 0", self.content)
        self.assertIn("mark[1] <= line_count", self.content)

    def test_close_with_q_filetype_autocmd(self):
        """FileType autocmd must register 'q' for closing auxiliary buffers."""
        self.assertIn('"help"', self.content)
        self.assertIn('"lspinfo"', self.content)
        self.assertIn('"q"', self.content)
        self.assertIn('"<cmd>close<CR>"', self.content)

    def test_close_with_q_marks_not_listed(self):
        """Auxiliary buffers closed with q must be marked as not listed."""
        self.assertIn("buflisted = false", self.content)

    def test_qf_in_close_with_q(self):
        """Quickfix buffers must be closeable with q."""
        self.assertIn('"qf"', self.content)

    def test_checkhealth_in_close_with_q(self):
        """checkhealth buffers must be closeable with q."""
        self.assertIn('"checkhealth"', self.content)

    def test_query_in_close_with_q(self):
        """treesitter query editor must be closeable with q."""
        self.assertIn('"query"', self.content)

    def test_filetype_indent_web_files_2_spaces(self):
        """Web and config files must use 2-space indentation."""
        self.assertIn('"lua"', self.content)
        self.assertIn('"javascript"', self.content)
        self.assertIn('"typescript"', self.content)
        self.assertIn('"json"', self.content)
        self.assertIn('"yaml"', self.content)
        self.assertIn('"toml"', self.content)
        self.assertIn('"html"', self.content)
        self.assertIn('"css"', self.content)
        self.assertIn('"markdown"', self.content)

    def test_2_space_indent_value(self):
        """2-space indent filetypes must set tabstop/shiftwidth/softtabstop to 2."""
        # Should have multiple assignments to 2 in the indent callbacks
        assignments_to_2 = re.findall(r'(?:tabstop|shiftwidth|softtabstop)\s*=\s*2',
                                      self.content)
        self.assertGreaterEqual(len(assignments_to_2), 3,
                                "Expected tabstop, shiftwidth, softtabstop all = 2")

    def test_filetype_indent_c_cpp_4_spaces(self):
        """C/C++ files must use 4-space indentation."""
        self.assertIn('"c"', self.content)
        self.assertIn('"cpp"', self.content)
        # 4-space assignments
        assignments_to_4 = re.findall(r'(?:tabstop|shiftwidth|softtabstop)\s*=\s*4',
                                      self.content)
        self.assertGreaterEqual(len(assignments_to_4), 3,
                                "Expected tabstop, shiftwidth, softtabstop all = 4")

    def test_makefile_uses_tabs(self):
        """Makefile must use tabs (not spaces) for indentation."""
        self.assertIn('"make"', self.content)
        self.assertIn("expandtab = false", self.content)

    def test_spell_enabled_for_prose(self):
        """Spell checking must be enabled for markdown, text, gitcommit, rst."""
        self.assertIn('"markdown"', self.content)
        self.assertIn('"text"', self.content)
        self.assertIn('"gitcommit"', self.content)
        self.assertIn('"rst"', self.content)
        self.assertIn("spell    = true", self.content)
        self.assertIn('"en_us"', self.content)

    def test_prose_enables_wrap(self):
        """Prose filetypes must enable line wrapping."""
        self.assertIn("wrap     = true", self.content)
        self.assertIn("linebreak = true", self.content)

    def test_auto_mkdir_on_write(self):
        """BufWritePre autocmd must auto-create parent directories."""
        self.assertIn('"BufWritePre"', self.content)
        self.assertIn('vim.fn.mkdir', self.content)
        self.assertIn('":p:h"', self.content)

    def test_auto_mkdir_skips_remote_urls(self):
        """auto_mkdir must skip remote URIs (e.g. ssh://, https://)."""
        # Check for a URL-detection pattern in the auto_mkdir callback
        self.assertIn("^%w%w+:", self.content)

    def test_strip_whitespace_is_conditional(self):
        """Strip whitespace must only be active when NVIM_STRIP_WHITESPACE=1."""
        self.assertIn('NVIM_STRIP_WHITESPACE', self.content)
        self.assertIn('"1"', self.content)
        # The autocmd registration should be inside the if block
        strip_idx = self.content.find('NVIM_STRIP_WHITESPACE')
        autocmd_idx = self.content.find('strip_whitespace', strip_idx)
        self.assertGreater(autocmd_idx, strip_idx,
                           "strip_whitespace autocmd must be inside the env check")

    def test_terminal_auto_insert(self):
        """Terminal buffers must auto-enter insert mode."""
        self.assertIn('"TermOpen"', self.content)
        self.assertIn('"BufEnter"', self.content)
        self.assertIn("startinsert", self.content)

    def test_terminal_hides_line_numbers(self):
        """Terminal buffers must hide line numbers."""
        self.assertIn("number         = false", self.content)
        self.assertIn("relativenumber = false", self.content)
        self.assertIn('signcolumn     = "no"', self.content)

    def test_terminal_pattern_is_term(self):
        """Terminal autocmd must match 'term://*' pattern."""
        self.assertIn('"term://*"', self.content)

    def test_lsp_attach_autocmd(self):
        """LspAttach autocmd must be registered."""
        self.assertIn('"LspAttach"', self.content)

    def test_lsp_semantic_tokens_disabled_for_large_files(self):
        """Semantic tokens must be disabled for files over 5000 lines."""
        self.assertIn("5000", self.content)
        self.assertIn("semanticTokensProvider = nil", self.content)

    def test_treesitter_folding_for_supported_filetypes(self):
        """Treesitter-based folding must be set up for key filetypes."""
        self.assertIn('"rust"', self.content)
        self.assertIn('"python"', self.content)
        self.assertIn('"bash"', self.content)
        self.assertIn("foldmethod", self.content)
        self.assertIn("foldexpr", self.content)

    def test_folding_uses_pcall_for_safety(self):
        """Treesitter folding setup must use pcall to guard against missing parsers."""
        self.assertIn("pcall(vim.treesitter.get_parser", self.content)

    def test_folding_disabled_by_default(self):
        """Folding must be disabled by default (open all folds)."""
        self.assertIn("foldenable = false", self.content)

    def test_all_augroups_use_helper(self):
        """All autocmd group= assignments must go through the augroup() helper."""
        # Match only `  group = ...` lines (not higroup or other *group variants)
        # Use a strict pattern: optional whitespace + exactly "group" as a word
        groups = re.findall(r'^\s*group\s*=\s*(.+?)(?:,|$)', self.content,
                            re.MULTILINE)
        for g in groups:
            self.assertTrue(
                g.strip().startswith("augroup("),
                f"group assignment '{g.strip()}' does not use augroup() helper"
            )


class TestAutocmdsAugroupNaming(unittest.TestCase):
    """Test augroup naming conventions in autocmds.lua."""

    def setUp(self):
        self.content = read_core("autocmds.lua")
        self.names = find_augroup_names(self.content)

    def test_augroup_names_are_snake_case(self):
        """Augroup names should use snake_case."""
        for name in self.names:
            self.assertRegex(name, r'^[a-z][a-z0-9_]*$',
                             f"Augroup name '{name}' should be snake_case")

    def test_expected_augroup_names_present(self):
        """All expected augroup names must be present."""
        expected = {
            "highlight_yank",
            "resize_splits",
            "restore_cursor",
            "close_with_q",
            "ft_indent",
            "ft_indent_c",
            "spell_prose",
            "auto_mkdir",
            "terminal_auto_insert",
            "lsp_performance",
        }
        for name in expected:
            self.assertIn(name, self.names,
                          f"Expected augroup 'config_{name}' not found")

    def test_no_duplicate_augroup_names(self):
        """No augroup name should appear twice (would indicate copy-paste error)."""
        seen = set()
        for name in self.names:
            self.assertNotIn(name, seen,
                             f"Duplicate augroup name: '{name}'")
            seen.add(name)


# ============================================================================
# Tests for lua/core/options.lua
# ============================================================================

class TestOptionsStructure(unittest.TestCase):
    """Tests for lua/core/options.lua — key option values."""

    def setUp(self):
        self.content = read_core("options.lua")

    def test_file_exists(self):
        """lua/core/options.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(CORE_DIR, "options.lua")))

    def test_local_opt_alias(self):
        """Must use a local opt alias for vim.opt."""
        self.assertIn("local opt = vim.opt", self.content)

    def test_updatetime_250(self):
        """updatetime must be 250ms for responsive CursorHold events."""
        self.assertIn("opt.updatetime  = 250", self.content)

    def test_timeoutlen_400(self):
        """timeoutlen must be 400ms for key sequence timeout."""
        self.assertIn("opt.timeoutlen  = 400", self.content)

    def test_swapfile_disabled(self):
        """Swap files must be disabled."""
        self.assertIn("opt.swapfile    = false", self.content)

    def test_backup_disabled(self):
        """Backup files must be disabled."""
        self.assertIn("opt.backup      = false", self.content)

    def test_undofile_enabled(self):
        """Persistent undo must be enabled."""
        self.assertIn("opt.undofile    = true", self.content)

    def test_termguicolors_enabled(self):
        """True-color support must be enabled."""
        self.assertIn("opt.termguicolors = true", self.content)

    def test_line_numbers_enabled(self):
        """Absolute line numbers must be enabled."""
        self.assertIn("opt.number        = true", self.content)

    def test_relative_line_numbers_enabled(self):
        """Relative line numbers must be enabled."""
        self.assertIn("opt.relativenumber = true", self.content)

    def test_sign_column_always_visible(self):
        """Sign column must always be visible to prevent layout shift."""
        self.assertIn('opt.signcolumn    = "yes:1"', self.content)

    def test_cursor_line_enabled(self):
        """Cursor line highlighting must be enabled."""
        self.assertIn("opt.cursorline    = true", self.content)

    def test_color_column_set(self):
        """Color column must be set for line-length guidance."""
        self.assertIn('opt.colorcolumn   = "88,120"', self.content)

    def test_wrap_disabled(self):
        """Line wrapping must be disabled by default."""
        self.assertIn("opt.wrap          = false", self.content)

    def test_scrolloff_8(self):
        """scrolloff must be 8 lines."""
        self.assertIn("opt.scrolloff     = 8", self.content)

    def test_sidescrolloff_8(self):
        """sidescrolloff must be 8 columns."""
        self.assertIn("opt.sidescrolloff = 8", self.content)

    def test_laststatus_3(self):
        """laststatus must be 3 for global statusline."""
        self.assertIn("opt.laststatus    = 3", self.content)

    def test_split_below(self):
        """Splits must open below by default."""
        self.assertIn("opt.splitbelow    = true", self.content)

    def test_split_right(self):
        """Splits must open to the right by default."""
        self.assertIn("opt.splitright    = true", self.content)

    def test_hlsearch_enabled(self):
        """Search highlighting must be enabled."""
        self.assertIn("opt.hlsearch   = true", self.content)

    def test_ignorecase_enabled(self):
        """Case-insensitive search must be enabled."""
        self.assertIn("opt.ignorecase = true", self.content)

    def test_smartcase_enabled(self):
        """Smart case (uppercase overrides ignorecase) must be enabled."""
        self.assertIn("opt.smartcase  = true", self.content)

    def test_ripgrep_grepprg(self):
        """grep program must use ripgrep for speed."""
        self.assertIn("rg --vimgrep --smart-case", self.content)

    def test_expandtab_enabled(self):
        """Spaces must be used instead of tabs by default."""
        self.assertIn("opt.expandtab   = true", self.content)

    def test_tabstop_4(self):
        """Default tabstop must be 4 spaces."""
        self.assertIn("opt.tabstop     = 4", self.content)

    def test_shiftwidth_4(self):
        """Default shiftwidth must be 4 spaces."""
        self.assertIn("opt.shiftwidth  = 4", self.content)

    def test_softtabstop_4(self):
        """Default softtabstop must be 4 spaces."""
        self.assertIn("opt.softtabstop = 4", self.content)

    def test_smartindent_enabled(self):
        """Smart auto-indent must be enabled."""
        self.assertIn("opt.smartindent = true", self.content)

    def test_list_enabled(self):
        """List mode must be enabled to show special characters."""
        self.assertIn("opt.list        = true", self.content)

    def test_listchars_tab_character(self):
        """Tab character must have a visible representation."""
        self.assertIn("tab", self.content)
        self.assertIn("→", self.content)

    def test_listchars_trail_character(self):
        """Trailing spaces must have a visible representation."""
        self.assertIn("trail", self.content)
        self.assertIn("·", self.content)

    def test_fold_method_manual_default(self):
        """Fold method must start as manual (plugins switch to expr)."""
        self.assertIn('opt.foldmethod  = "manual"', self.content)

    def test_foldenable_false(self):
        """Folding must be disabled by default (all folds open)."""
        self.assertIn("opt.foldenable  = false", self.content)

    def test_clipboard_empty_by_default(self):
        """Clipboard must be empty by default (no unnamedplus over SSH)."""
        self.assertIn('opt.clipboard = ""', self.content)

    def test_clipboard_conditional_on_env_var(self):
        """Clipboard integration must only be enabled when NVIM_CLIPBOARD=1."""
        self.assertIn("NVIM_CLIPBOARD", self.content)
        self.assertIn('"unnamedplus"', self.content)

    def test_python_path_from_env(self):
        """Python provider path must come from NVIM_PYTHON_PATH env var."""
        self.assertIn("NVIM_PYTHON_PATH", self.content)
        self.assertIn("python3_host_prog", self.content)

    def test_python_provider_disabled_when_no_path(self):
        """Python provider must be disabled when NVIM_PYTHON_PATH is not set."""
        self.assertIn("loaded_python3_provider = 0", self.content)

    def test_ruby_provider_disabled(self):
        """Ruby provider must be disabled (not used)."""
        self.assertIn("loaded_ruby_provider   = 0", self.content)

    def test_perl_provider_disabled(self):
        """Perl provider must be disabled (not used)."""
        self.assertIn("loaded_perl_provider   = 0", self.content)

    def test_node_provider_disabled(self):
        """Node provider must be disabled (not used by default)."""
        self.assertIn("loaded_node_provider   = 0", self.content)

    def test_spell_disabled_globally(self):
        """Spell checking must be disabled globally (enabled per filetype)."""
        self.assertIn("opt.spell     = false", self.content)

    def test_undodir_created(self):
        """Undo directory must be created if it doesn't exist."""
        self.assertIn("vim.fn.mkdir", self.content)
        self.assertIn('"/undo"', self.content)

    def test_showmode_disabled(self):
        """showmode must be disabled (statusline shows mode instead)."""
        self.assertIn("opt.showmode      = false", self.content)

    def test_undolevels_high(self):
        """undolevels must be set high for deep undo history."""
        m = re.search(r'opt\.undolevels\s*=\s*(\d+)', self.content)
        self.assertIsNotNone(m)
        self.assertGreaterEqual(int(m.group(1)), 1000)

    def test_pumheight_set(self):
        """Popup menu height must be configured."""
        m = re.search(r'opt\.pumheight\s*=\s*(\d+)', self.content)
        self.assertIsNotNone(m)
        self.assertGreater(int(m.group(1)), 0)

    def test_encoding_utf8(self):
        """File encoding must be UTF-8."""
        self.assertIn('"utf-8"', self.content)

    def test_diff_option_linematch(self):
        """Diff option must include linematch for better diffs."""
        self.assertIn("linematch", self.content)

    def test_confirm_enabled(self):
        """confirm must be true to ask before discarding changes."""
        self.assertIn("opt.confirm        = true", self.content)

    def test_joinspaces_disabled(self):
        """joinspaces must be false (no double space after period)."""
        self.assertIn("opt.joinspaces     = false", self.content)


# ============================================================================
# Tests for lua/core/keymaps.lua
# ============================================================================

class TestKeymapsStructure(unittest.TestCase):
    """Tests for lua/core/keymaps.lua — key mapping definitions."""

    def setUp(self):
        self.content = read_core("keymaps.lua")

    def test_file_exists(self):
        """lua/core/keymaps.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(CORE_DIR, "keymaps.lua")))

    def test_map_helper_defined(self):
        """A local map() helper function must be defined."""
        self.assertIn("local map = function(mode, lhs, rhs, opts)", self.content)

    def test_map_helper_uses_silent(self):
        """map() helper must set silent = true by default."""
        self.assertIn("silent = true", self.content)

    def test_map_helper_uses_noremap(self):
        """map() helper must set noremap = true by default."""
        self.assertIn("noremap = true", self.content)

    def test_map_helper_uses_tbl_extend(self):
        """map() helper must use vim.tbl_extend to merge options."""
        self.assertIn("vim.tbl_extend", self.content)

    def test_mapleader_space(self):
        """mapleader must be set to space."""
        self.assertIn('vim.g.mapleader      = " "', self.content)

    def test_maplocalleader_backslash(self):
        """maplocalleader must be set to backslash."""
        self.assertIn('vim.g.maplocalleader = "\\\\"', self.content)

    def test_window_nav_ctrl_h(self):
        """Ctrl-H must navigate to the left window."""
        self.assertIn('"<C-h>"', self.content)
        self.assertIn('"<C-w>h"', self.content)

    def test_window_nav_ctrl_j(self):
        """Ctrl-J must navigate to the window below."""
        self.assertIn('"<C-j>"', self.content)
        self.assertIn('"<C-w>j"', self.content)

    def test_window_nav_ctrl_k(self):
        """Ctrl-K must navigate to the window above."""
        self.assertIn('"<C-k>"', self.content)
        self.assertIn('"<C-w>k"', self.content)

    def test_window_nav_ctrl_l(self):
        """Ctrl-L must navigate to the right window."""
        self.assertIn('"<C-l>"', self.content)
        self.assertIn('"<C-w>l"', self.content)

    def test_esc_clears_search_highlight(self):
        """Escape must clear search highlights."""
        self.assertIn('"<Esc>"', self.content)
        self.assertIn("nohlsearch", self.content)

    def test_leader_w_saves_file(self):
        """<leader>w must save the current file."""
        self.assertIn('"<leader>w"', self.content)
        self.assertIn('"<cmd>write<CR>"', self.content)

    def test_leader_q_quits(self):
        """<leader>q must quit with confirmation."""
        self.assertIn('"<leader>q"', self.content)
        self.assertIn("confirm quit", self.content)

    def test_leader_q_all_quits_all(self):
        """<leader>Q must quit all with confirmation."""
        self.assertIn('"<leader>Q"', self.content)
        self.assertIn("confirm quitall", self.content)

    def test_shift_h_prev_buffer(self):
        """Shift-H must navigate to previous buffer."""
        self.assertIn('"<S-h>"', self.content)
        self.assertIn("bprevious", self.content)

    def test_shift_l_next_buffer(self):
        """Shift-L must navigate to next buffer."""
        self.assertIn('"<S-l>"', self.content)
        self.assertIn("bnext", self.content)

    def test_leader_bd_buffer_delete(self):
        """<leader>bd must delete the current buffer."""
        self.assertIn('"<leader>bd"', self.content)
        self.assertIn("bdelete", self.content)

    def test_scroll_down_centered(self):
        """Ctrl-D scroll must keep cursor centered."""
        self.assertIn('"<C-d>"', self.content)
        self.assertIn('"<C-d>zz"', self.content)

    def test_scroll_up_centered(self):
        """Ctrl-U scroll must keep cursor centered."""
        self.assertIn('"<C-u>"', self.content)
        self.assertIn('"<C-u>zz"', self.content)

    def test_join_lines_keeps_cursor(self):
        """J (join lines) must preserve cursor position."""
        self.assertIn('"mzJ`z"', self.content)

    def test_visual_indent_stay_in_mode(self):
        """Indent in visual mode must keep selection active."""
        self.assertIn('"<"', self.content)
        self.assertIn('"<gv"', self.content)
        self.assertIn('">"', self.content)
        self.assertIn('">gv"', self.content)

    def test_paste_without_yank_in_visual(self):
        """Paste in visual mode must not overwrite the unnamed register."""
        # In Lua, '"_dP' uses single quotes wrapping a double-quote prefix
        self.assertIn('"_dP', self.content)

    def test_x_no_yank_in_normal(self):
        """x (delete char) must not yank in normal mode."""
        # In Lua, '"_x' uses single quotes; the mapped rhs sends to black hole register
        self.assertIn('"_x', self.content)

    def test_yank_to_system_clipboard(self):
        """<leader>y must yank to system clipboard."""
        self.assertIn('"<leader>y"', self.content)
        self.assertIn('\'"+y\'', self.content)

    def test_paste_from_system_clipboard(self):
        """<leader>p must paste from system clipboard."""
        self.assertIn('"<leader>p"', self.content)
        self.assertIn('\'"+p\'', self.content)

    def test_terminal_escape(self):
        """Esc-Esc must exit terminal mode."""
        self.assertIn('"<Esc><Esc>"', self.content)
        self.assertIn('"<C-\\\\><C-n>"', self.content)

    def test_terminal_window_nav(self):
        """Window navigation keys must work from terminal mode."""
        # The wincmd navigation is inside the <cmd>...<CR> wrapper
        self.assertIn("wincmd h", self.content)
        self.assertIn("wincmd j", self.content)
        self.assertIn("wincmd k", self.content)
        self.assertIn("wincmd l", self.content)

    def test_jk_escape_in_insert(self):
        """jk must be an alternative escape in insert mode."""
        self.assertIn('"jk"', self.content)
        self.assertIn('"<Esc>"', self.content)

    def test_quickfix_navigation(self):
        """Quickfix list navigation must be mapped."""
        self.assertIn('"[q"', self.content)
        self.assertIn('"]q"', self.content)
        self.assertIn("cprevious", self.content)
        self.assertIn("cnext", self.content)

    def test_location_list_navigation(self):
        """Location list navigation must be mapped."""
        self.assertIn('"[l"', self.content)
        self.assertIn('"]l"', self.content)

    def test_tab_operations(self):
        """Tab new/close operations must be mapped."""
        self.assertIn('"<leader>tn"', self.content)
        self.assertIn('"<leader>tc"', self.content)
        self.assertIn("tabnew", self.content)
        self.assertIn("tabclose", self.content)

    def test_move_lines_alt_j(self):
        """Alt-J must move lines down."""
        self.assertIn('"<A-j>"', self.content)

    def test_move_lines_alt_k(self):
        """Alt-K must move lines up."""
        self.assertIn('"<A-k>"', self.content)

    def test_0_12_reserved_keymaps_not_remapped(self):
        """Neovim 0.12 default LSP keymaps must not be remapped."""
        # gra, gri, grn, grr, grt, grx, gO are 0.12 defaults
        # They must NOT appear in map() calls (they are set by neovim itself)
        map_calls = re.findall(r'map\([^,]+,\s*"([^"]+)"', self.content)
        reserved = {"gra", "gri", "grn", "grr", "grt", "grx", "gO"}
        for key in map_calls:
            self.assertNotIn(key, reserved,
                             f"Key '{key}' is a Neovim 0.12 default — do not remap")

    def test_n_next_match_is_direction_aware(self):
        """n/N must always go forward/backward regardless of search direction."""
        self.assertIn("v:searchforward", self.content)

    def test_diagnostic_open_float(self):
        """<leader>e must open diagnostic float."""
        self.assertIn('"<leader>e"', self.content)
        self.assertIn("diagnostic.open_float", self.content)

    def test_diagnostic_location_list(self):
        """<leader>dl must open diagnostic location list."""
        self.assertIn('"<leader>dl"', self.content)
        self.assertIn("setloclist", self.content)

    def test_treesitter_textobj_select_defined(self):
        """Treesitter text-object select keymaps must be defined."""
        self.assertIn("select_textobject", self.content)

    def test_treesitter_move_keymaps_defined(self):
        """Treesitter movement keymaps must be defined."""
        self.assertIn("goto_next", self.content)

    def test_treesitter_swap_keymaps_defined(self):
        """Treesitter swap keymaps must be defined."""
        self.assertIn("swap_next", self.content)
        self.assertIn("swap_previous", self.content)

    def test_repeatable_move_optional(self):
        """Repeatable move integration must be guarded with pcall."""
        self.assertIn("repeatable_move", self.content)
        self.assertIn("pcall(require", self.content)


# ============================================================================
# Tests for lua/core/treesitter.lua
# ============================================================================

class TestTreesitterModule(unittest.TestCase):
    """Tests for lua/core/treesitter.lua — native treesitter highlighting."""

    def setUp(self):
        self.content = read_core("treesitter.lua")

    def test_file_exists(self):
        """lua/core/treesitter.lua must exist."""
        self.assertTrue(os.path.exists(os.path.join(CORE_DIR, "treesitter.lua")))

    def test_filetype_autocmd_registered(self):
        """A FileType autocmd must be registered to enable treesitter."""
        self.assertIn("nvim_create_autocmd", self.content)
        self.assertIn('"FileType"', self.content)

    def test_uses_pcall_for_safety(self):
        """vim.treesitter.start must be called via pcall to handle missing parsers."""
        self.assertIn("pcall", self.content)
        self.assertIn("vim.treesitter.start", self.content)

    def test_disables_syntax_on_success(self):
        """When treesitter starts successfully, vim syntax must be disabled."""
        self.assertIn('syntax = "off"', self.content)

    def test_syntax_disabled_conditionally(self):
        """syntax = 'off' must only be set when pcall succeeds."""
        # The assignment must be inside the `if ok then` block
        ok_idx = self.content.find("if ok then")
        syntax_idx = self.content.find('syntax = "off"')
        self.assertGreater(syntax_idx, ok_idx,
                           "syntax = 'off' must be inside 'if ok then' block")

    def test_uses_ev_buf(self):
        """The FileType callback must pass ev.buf to treesitter.start."""
        self.assertIn("ev.buf", self.content)

    def test_desc_present(self):
        """The autocmd should have a description."""
        self.assertIn("desc", self.content)
        self.assertIn("treesitter", self.content.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)