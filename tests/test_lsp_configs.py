"""
Tests for lsp/*.lua — LSP server configuration files.

These tests validate the structure and content of each LSP config file
by parsing them as text. This approach works without a Lua runtime or
Neovim installation.

Each LSP config must:
  - Reference the correct NVIM_*_PATH environment variable in cmd
  - Declare a non-empty filetypes list
  - Include ".git" in root_markers as a safety fallback
  - Provide a settings (or init_options) table

Additional server-specific invariants are also checked.
"""

import re
import os
import unittest

LSP_DIR = os.path.join(os.path.dirname(__file__), "..", "lsp")


def read_lsp(filename):
    """Return the contents of lsp/<filename>."""
    path = os.path.join(LSP_DIR, filename)
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def has_field(content, field):
    """True if `field` appears as a Lua table key in *content*."""
    return bool(re.search(r'\b' + re.escape(field) + r'\s*=', content))


def has_env_var(content, var_name):
    """True if vim.env.VAR_NAME appears in content."""
    return ("vim.env." + var_name) in content


def has_git_root_marker(content):
    """True if the string '".git"' appears inside a root_markers table."""
    # Accept both bare ".git" entries and inline lists
    return '".git"' in content


def has_filetypes(content):
    """True if filetypes key is declared with at least one entry."""
    m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', content, re.DOTALL)
    if not m:
        return False
    inner = m.group(1).strip()
    return bool(re.search(r'"[^"]+"', inner))


class TestBashLsConfig(unittest.TestCase):
    """Tests for lsp/bashls.lua (bash-language-server)."""

    def setUp(self):
        self.content = read_lsp("bashls.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_BASHLS_PATH from the environment."""
        self.assertTrue(has_env_var(self.content, "NVIM_BASHLS_PATH"),
                        "NVIM_BASHLS_PATH not referenced in cmd")

    def test_cmd_has_start_subcommand(self):
        """bash-language-server is invoked with 'start' subcommand."""
        self.assertIn('"start"', self.content)

    def test_filetypes_present(self):
        """filetypes must be a non-empty list."""
        self.assertTrue(has_filetypes(self.content))

    def test_filetypes_includes_sh_and_bash(self):
        """sh and bash must be handled by this server."""
        self.assertIn('"sh"', self.content)
        self.assertIn('"bash"', self.content)

    def test_filetypes_includes_zsh(self):
        """zsh must also be in filetypes."""
        self.assertIn('"zsh"', self.content)

    def test_git_in_root_markers(self):
        """root_markers must include '.git' as a fallback."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_settings_bash_ide_section(self):
        """settings must have a bashIde section."""
        self.assertIn("bashIde", self.content)

    def test_source_error_diagnostics_disabled(self):
        """enableSourceErrorDiagnostics must be false (too noisy)."""
        self.assertIn("enableSourceErrorDiagnostics = false", self.content)

    def test_explain_shell_endpoint_empty(self):
        """explainshellEndpoint must be empty (no external service calls)."""
        self.assertIn('explainshellEndpoint', self.content)
        m = re.search(r'explainshellEndpoint\s*=\s*"([^"]*)"', self.content)
        self.assertIsNotNone(m)
        self.assertEqual(m.group(1), "",
                         "explainshellEndpoint must be empty to avoid external calls")

    def test_background_analysis_limit(self):
        """backgroundAnalysisMaxFiles must be set to limit resource usage."""
        self.assertIn("backgroundAnalysisMaxFiles", self.content)
        m = re.search(r'backgroundAnalysisMaxFiles\s*=\s*(\d+)', self.content)
        self.assertIsNotNone(m)
        limit = int(m.group(1))
        self.assertGreater(limit, 0)
        self.assertLessEqual(limit, 2000,
                             "backgroundAnalysisMaxFiles seems unreasonably large")


class TestClangConfig(unittest.TestCase):
    """Tests for lsp/clang.lua (clangd — C/C++/embedded)."""

    def setUp(self):
        self.content = read_lsp("clang.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_CLANGD_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_CLANGD_PATH"))

    def test_filetypes_include_c_and_cpp(self):
        """C and C++ must be handled."""
        self.assertIn('"c"', self.content)
        self.assertIn('"cpp"', self.content)

    def test_filetypes_include_objc(self):
        """Objective-C must be handled."""
        self.assertIn('"objc"', self.content)

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_compile_commands_in_root_markers(self):
        """compile_commands.json must be a root marker (ESP-IDF / CMake)."""
        self.assertIn('"compile_commands.json"', self.content)

    def test_utf16_offset_encoding_in_cmd(self):
        """--offset-encoding=utf-16 must be in cmd (avoids encoding conflicts)."""
        self.assertIn("--offset-encoding=utf-16", self.content)

    def test_utf16_in_capabilities(self):
        """capabilities must declare utf-16 offset encoding."""
        self.assertIn("offsetEncoding", self.content)
        self.assertIn('"utf-16"', self.content)

    def test_background_index_enabled(self):
        """--background-index should be in cmd for cross-reference support."""
        self.assertIn("--background-index", self.content)

    def test_clang_tidy_enabled(self):
        """--clang-tidy should be passed to enable linting."""
        self.assertIn("--clang-tidy", self.content)

    def test_worker_limit(self):
        """--j=N must limit background indexing workers (SSH / embedded)."""
        self.assertRegex(self.content, r'--j=\d+')

    def test_log_level_error(self):
        """Log level must be error (reduces SSH terminal noise)."""
        self.assertIn("--log=error", self.content)

    def test_use_placeholders_in_init_options(self):
        """usePlaceholders should be enabled for better completion."""
        self.assertIn("usePlaceholders", self.content)

    def test_complete_unimported(self):
        """completeUnimported enables completions from unincluded headers."""
        self.assertIn("completeUnimported", self.content)


class TestJsonLsConfig(unittest.TestCase):
    """Tests for lsp/jsonls.lua (vscode-json-language-server)."""

    def setUp(self):
        self.content = read_lsp("jsonls.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_JSONLS_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_JSONLS_PATH"))

    def test_stdio_flag(self):
        """jsonls is invoked with --stdio."""
        self.assertIn('"--stdio"', self.content)

    def test_filetypes_json_and_jsonc(self):
        """Both json and jsonc filetypes must be listed."""
        self.assertIn('"json"', self.content)
        self.assertIn('"jsonc"', self.content)

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_snippet_support_capability(self):
        """snippetSupport must be true (required for jsonls completion)."""
        self.assertIn("snippetSupport = true", self.content)

    def test_schemas_present(self):
        """At least one JSON schema must be configured."""
        self.assertIn("schemas", self.content)
        self.assertIn("fileMatch", self.content)

    def test_package_json_schema(self):
        """package.json schema should be registered."""
        self.assertIn('"package.json"', self.content)
        self.assertIn("schemastore.org", self.content)

    def test_tsconfig_schema(self):
        """tsconfig*.json schema should be registered."""
        self.assertIn('"tsconfig*.json"', self.content)

    def test_validation_enabled(self):
        """Validation must be enabled."""
        self.assertIn("validate = { enable = true }", self.content)

    def test_format_disabled(self):
        """Formatter must be disabled (we use conform.nvim)."""
        self.assertIn("format   = { enable = false }", self.content)


class TestLuaLsConfig(unittest.TestCase):
    """Tests for lsp/lua_ls.lua (Lua language server)."""

    def setUp(self):
        self.content = read_lsp("lua_ls.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_LUA_LS_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_LUA_LS_PATH"))

    def test_filetypes_lua_only(self):
        """Only 'lua' filetype should be listed."""
        m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', self.content)
        self.assertIsNotNone(m)
        entries = re.findall(r'"([^"]+)"', m.group(1))
        self.assertEqual(entries, ["lua"],
                         "lua_ls should only activate for Lua files")

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_luarc_json_in_root_markers(self):
        """.luarc.json must be a root marker."""
        self.assertIn('".luarc.json"', self.content)

    def test_runtime_luajit(self):
        """Runtime version must be LuaJIT (Neovim embeds LuaJIT)."""
        self.assertIn('"LuaJIT"', self.content)

    def test_check_third_party_false(self):
        """checkThirdParty must be false (lazydev handles workspace libs)."""
        self.assertIn("checkThirdParty = false", self.content)

    def test_telemetry_disabled(self):
        """Telemetry must be disabled."""
        self.assertIn("telemetry = { enable = false }", self.content)

    def test_format_disabled(self):
        """Formatter must be disabled (we use stylua via conform.nvim)."""
        self.assertIn("enable = false", self.content)
        # Should specifically be in a format section
        self.assertIn("format", self.content)

    def test_vim_global_in_diagnostics(self):
        """'vim' must be listed as a known global to avoid false warnings."""
        self.assertIn('"vim"', self.content)

    def test_call_snippet_replace(self):
        """callSnippet should be 'Replace' for better UX."""
        self.assertIn('"Replace"', self.content)

    def test_inlay_hints_enabled(self):
        """Inlay hints must be enabled."""
        self.assertIn("enable       = true", self.content)

    def test_missing_fields_disabled(self):
        """missing-fields diagnostic must be suppressed (too noisy with lazydev)."""
        self.assertIn('"missing-fields"', self.content)


class TestPyrightConfig(unittest.TestCase):
    """Tests for lsp/pyright.lua (Pyright type checker)."""

    def setUp(self):
        self.content = read_lsp("pyright.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_PYRIGHT_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_PYRIGHT_PATH"))

    def test_stdio_flag(self):
        """Pyright runs with --stdio."""
        self.assertIn('"--stdio"', self.content)

    def test_filetypes_python_only(self):
        """Only 'python' filetype should be listed."""
        m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', self.content)
        self.assertIsNotNone(m)
        entries = re.findall(r'"([^"]+)"', m.group(1))
        self.assertEqual(entries, ["python"])

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_pyproject_toml_in_root_markers(self):
        """pyproject.toml must be a root marker."""
        self.assertIn('"pyproject.toml"', self.content)

    def test_auto_search_paths_disabled(self):
        """autoSearchPaths must be false (explicit Python path required)."""
        self.assertIn("autoSearchPaths      = false", self.content)

    def test_python_path_env_var(self):
        """NVIM_PYTHON_PATH must be referenced for the interpreter path."""
        self.assertTrue(has_env_var(self.content, "NVIM_PYTHON_PATH"))

    def test_before_init_function_present(self):
        """before_init must be present to clear venvPath/venv."""
        self.assertIn("before_init", self.content)
        self.assertIn("function", self.content)

    def test_venv_path_cleared(self):
        """before_init must set venvPath to nil."""
        self.assertIn("venvPath = nil", self.content)

    def test_venv_cleared(self):
        """before_init must set venv to nil."""
        self.assertIn("venv     = nil", self.content)

    def test_open_files_only_diagnostic_mode(self):
        """diagnosticMode must be openFilesOnly (faster for large projects)."""
        self.assertIn('"openFilesOnly"', self.content)

    def test_basic_type_checking_mode(self):
        """typeCheckingMode should be 'basic' (balanced strictness)."""
        self.assertIn('"basic"', self.content)

    def test_inlay_hints_configured(self):
        """inlayHints section must be present for Pyright."""
        self.assertIn("inlayHints", self.content)
        self.assertIn("variableTypes", self.content)
        self.assertIn("functionReturnTypes", self.content)

    def test_use_library_code_for_types(self):
        """useLibraryCodeForTypes must be true for better type inference."""
        self.assertIn("useLibraryCodeForTypes = true", self.content)


class TestRuffConfig(unittest.TestCase):
    """Tests for lsp/ruff.lua (Ruff linter/formatter as LSP)."""

    def setUp(self):
        self.content = read_lsp("ruff.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_RUFF_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_RUFF_PATH"))

    def test_server_subcommand(self):
        """Ruff must be invoked with 'server' subcommand (not ruff-lsp)."""
        self.assertIn('"server"', self.content)

    def test_filetypes_python_only(self):
        """Only 'python' filetype should be listed."""
        m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', self.content)
        self.assertIsNotNone(m)
        entries = re.findall(r'"([^"]+)"', m.group(1))
        self.assertEqual(entries, ["python"])

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_pyproject_toml_in_root_markers(self):
        """pyproject.toml must be a root marker."""
        self.assertIn('"pyproject.toml"', self.content)

    def test_ruff_toml_in_root_markers(self):
        """ruff.toml must be a root marker."""
        self.assertIn('"ruff.toml"', self.content)

    def test_hover_provider_disabled(self):
        """hoverProvider must be disabled (defer to Pyright's richer hover)."""
        self.assertIn("hoverProvider = false", self.content)

    def test_on_attach_function_present(self):
        """on_attach function must be present to disable hoverProvider."""
        self.assertIn("on_attach", self.content)

    def test_line_length_88(self):
        """lineLength should default to 88 (Black/PEP8 compatible)."""
        self.assertIn("lineLength         = 88", self.content)

    def test_organize_imports_enabled(self):
        """organizeImports must be true for isort-compatible sorting."""
        self.assertIn("organizeImports    = true", self.content)

    def test_fix_all_disabled(self):
        """fixAll must be false (use conform.nvim for controlled fixes)."""
        self.assertIn("fixAll             = false", self.content)

    def test_init_options_present(self):
        """init_options must be present with settings table."""
        self.assertIn("init_options", self.content)
        self.assertIn("settings", self.content)


class TestRustAnalyzerConfig(unittest.TestCase):
    """Tests for lsp/rust_analyzer.lua."""

    def setUp(self):
        self.content = read_lsp("rust_analyzer.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_RUST_ANALYZER_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_RUST_ANALYZER_PATH"))

    def test_filetypes_rust_only(self):
        """Only 'rust' filetype should be listed."""
        m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', self.content)
        self.assertIsNotNone(m)
        entries = re.findall(r'"([^"]+)"', m.group(1))
        self.assertEqual(entries, ["rust"])

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_cargo_toml_in_root_markers(self):
        """Cargo.toml must be a root marker."""
        self.assertIn('"Cargo.toml"', self.content)

    def test_check_on_save_uses_clippy(self):
        """checkOnSave must use clippy for better diagnostics."""
        self.assertIn('"clippy"', self.content)
        self.assertIn("checkOnSave", self.content)

    def test_all_features_enabled(self):
        """allFeatures must be true in cargo settings."""
        self.assertIn("allFeatures          = true", self.content)

    def test_proc_macro_enabled(self):
        """procMacro must be enabled."""
        self.assertIn("enable  = true", self.content)
        self.assertIn("procMacro", self.content)

    def test_inlay_hints_configured(self):
        """inlayHints section must be present."""
        self.assertIn("inlayHints", self.content)
        self.assertIn("parameterHints", self.content)
        self.assertIn("typeHints", self.content)

    def test_workspace_symbol_limit(self):
        """workspace symbol search must have a limit (SSH performance)."""
        self.assertIn("symbol", self.content)
        self.assertIn("limit", self.content)
        m = re.search(r'limit\s*=\s*(\d+)', self.content)
        self.assertIsNotNone(m)
        limit = int(m.group(1))
        self.assertLessEqual(limit, 512,
                             "symbol search limit should be bounded for SSH performance")

    def test_run_build_scripts_enabled(self):
        """runBuildScripts must be true for proc-macro support."""
        self.assertIn("runBuildScripts      = true", self.content)

    def test_no_deps_in_clippy_args(self):
        """clippy extra args should include --no-deps to avoid re-checking deps."""
        self.assertIn('"--no-deps"', self.content)

    def test_diagnostics_enabled(self):
        """Diagnostics must be enabled."""
        # Check for the diagnostics table with enable = true
        self.assertIn("diagnostics", self.content)
        self.assertIn("enable         = true", self.content)


class TestTaploConfig(unittest.TestCase):
    """Tests for lsp/taplo.lua (TOML language server)."""

    def setUp(self):
        self.content = read_lsp("taplo.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_TAPLO_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_TAPLO_PATH"))

    def test_lsp_stdio_subcommands(self):
        """taplo is invoked as 'taplo lsp stdio'."""
        self.assertIn('"lsp"', self.content)
        self.assertIn('"stdio"', self.content)

    def test_filetypes_toml_only(self):
        """Only 'toml' filetype should be listed."""
        m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', self.content)
        self.assertIsNotNone(m)
        entries = re.findall(r'"([^"]+)"', m.group(1))
        self.assertEqual(entries, ["toml"])

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_cargo_toml_in_root_markers(self):
        """Cargo.toml must be a root marker."""
        self.assertIn('"Cargo.toml"', self.content)

    def test_schema_enabled(self):
        """Schema validation must be enabled."""
        self.assertIn("enabled       = true", self.content)
        self.assertIn("schema", self.content)

    def test_cargo_toml_schema_association(self):
        """Cargo.toml must be associated with the taplo schema."""
        self.assertIn('"Cargo.toml"', self.content)
        self.assertIn("taplo://Cargo.toml", self.content)

    def test_pyproject_toml_schema_association(self):
        """pyproject.toml must be associated with its schema."""
        self.assertIn('"pyproject.toml"', self.content)
        self.assertIn("schemastore.org", self.content)

    def test_repository_enabled(self):
        """repositoryEnabled must be true for schema downloads."""
        self.assertIn("repositoryEnabled = true", self.content)


class TestYamlLsConfig(unittest.TestCase):
    """Tests for lsp/yamlls.lua (YAML language server)."""

    def setUp(self):
        self.content = read_lsp("yamlls.lua")

    def test_env_var_reference(self):
        """cmd must reference NVIM_YAMLLS_PATH."""
        self.assertTrue(has_env_var(self.content, "NVIM_YAMLLS_PATH"))

    def test_stdio_flag(self):
        """yamlls is invoked with --stdio."""
        self.assertIn('"--stdio"', self.content)

    def test_filetypes_yaml(self):
        """Standard 'yaml' filetype must be included."""
        self.assertIn('"yaml"', self.content)

    def test_filetypes_docker_compose(self):
        """yaml.docker-compose filetype must be included."""
        self.assertIn('"yaml.docker-compose"', self.content)

    def test_filetypes_github_actions(self):
        """yaml.github-actions filetype must be included."""
        self.assertIn('"yaml.github-actions"', self.content)

    def test_git_in_root_markers(self):
        """root_markers must include '.git'."""
        self.assertTrue(has_git_root_marker(self.content))

    def test_schema_store_enabled(self):
        """schemaStore must be enabled."""
        self.assertIn("schemaStore", self.content)
        self.assertIn("enable = true", self.content)

    def test_github_workflow_schema(self):
        """GitHub workflow schema must be configured."""
        self.assertIn("github-workflow.json", self.content)

    def test_docker_compose_schema(self):
        """Docker Compose schema must be configured."""
        self.assertIn("docker-compose", self.content)

    def test_format_disabled(self):
        """Formatter must be disabled (we use conform.nvim)."""
        self.assertIn("format             = { enable = false }", self.content)

    def test_redhat_telemetry_disabled(self):
        """Red Hat telemetry must be disabled."""
        self.assertIn("redhat", self.content)
        self.assertIn("telemetry", self.content)
        self.assertIn("enabled = false", self.content)

    def test_key_ordering_disabled(self):
        """keyOrdering must be false (don't enforce alphabetical order)."""
        self.assertIn("keyOrdering        = false", self.content)

    def test_validation_enabled(self):
        """YAML validation must be enabled."""
        self.assertIn("validate           = true", self.content)

    def test_completion_enabled(self):
        """Completion must be enabled."""
        self.assertIn("completion         = true", self.content)


class TestLspConfigConsistency(unittest.TestCase):
    """Cross-file consistency tests for all LSP configs."""

    # Map of filename → expected env var
    LSP_ENV_VARS = {
        "bashls.lua":        "NVIM_BASHLS_PATH",
        "clang.lua":         "NVIM_CLANGD_PATH",
        "jsonls.lua":        "NVIM_JSONLS_PATH",
        "lua_ls.lua":        "NVIM_LUA_LS_PATH",
        "pyright.lua":       "NVIM_PYRIGHT_PATH",
        "ruff.lua":          "NVIM_RUFF_PATH",
        "rust_analyzer.lua": "NVIM_RUST_ANALYZER_PATH",
        "taplo.lua":         "NVIM_TAPLO_PATH",
        "yamlls.lua":        "NVIM_YAMLLS_PATH",
    }

    def test_all_lsp_files_exist(self):
        """Every expected LSP config file must exist."""
        for fname in self.LSP_ENV_VARS:
            path = os.path.join(LSP_DIR, fname)
            self.assertTrue(os.path.exists(path),
                            f"Missing LSP config file: lsp/{fname}")

    def test_each_lsp_has_correct_env_var(self):
        """Each LSP config must reference its designated environment variable."""
        for fname, env_var in self.LSP_ENV_VARS.items():
            content = read_lsp(fname)
            self.assertIn(
                f"vim.env.{env_var}", content,
                f"lsp/{fname} must reference vim.env.{env_var} in cmd"
            )

    def test_each_lsp_has_git_root_marker(self):
        """Every LSP config must have '.git' in root_markers as a fallback."""
        for fname in self.LSP_ENV_VARS:
            content = read_lsp(fname)
            self.assertIn('".git"', content,
                          f"lsp/{fname} is missing '.git' in root_markers")

    def test_each_lsp_has_filetypes(self):
        """Every LSP config must declare a non-empty filetypes list."""
        for fname in self.LSP_ENV_VARS:
            content = read_lsp(fname)
            self.assertTrue(has_filetypes(content),
                            f"lsp/{fname} is missing a filetypes declaration")

    def test_no_duplicate_filetypes_across_non_python_servers(self):
        """
        Non-Python servers should not overlap in filetypes.
        Python servers (pyright + ruff) intentionally share 'python'.
        """
        non_python = {
            "bashls.lua", "clang.lua", "jsonls.lua",
            "lua_ls.lua", "rust_analyzer.lua", "taplo.lua", "yamlls.lua"
        }
        seen = {}
        for fname in non_python:
            content = read_lsp(fname)
            m = re.search(r'filetypes\s*=\s*\{([^}]+)\}', content)
            if not m:
                continue
            entries = re.findall(r'"([^"]+)"', m.group(1))
            for ft in entries:
                if ft in seen:
                    self.fail(
                        f"Filetype '{ft}' is handled by both "
                        f"lsp/{seen[ft]} and lsp/{fname}"
                    )
                seen[ft] = fname

    def test_python_servers_both_handle_python(self):
        """Both pyright and ruff must declare 'python' as a filetype."""
        for fname in ("pyright.lua", "ruff.lua"):
            content = read_lsp(fname)
            self.assertIn('"python"', content,
                          f"lsp/{fname} must handle 'python' filetype")

    def test_type_annotation_present(self):
        """Every LSP config should have the @type vim.lsp.Config annotation."""
        for fname in self.LSP_ENV_VARS:
            content = read_lsp(fname)
            self.assertIn("---@type vim.lsp.Config", content,
                          f"lsp/{fname} should have type annotation")

    def test_each_lsp_has_settings_or_init_options(self):
        """Every LSP config must have at least one configuration block."""
        settings_files = {
            "bashls.lua", "clang.lua", "jsonls.lua", "lua_ls.lua",
            "pyright.lua", "rust_analyzer.lua", "taplo.lua", "yamlls.lua"
        }
        init_options_files = {"clang.lua", "ruff.lua"}
        for fname in self.LSP_ENV_VARS:
            content = read_lsp(fname)
            has_settings = "settings" in content
            has_init_opts = "init_options" in content
            self.assertTrue(
                has_settings or has_init_opts,
                f"lsp/{fname} must have either 'settings' or 'init_options'"
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)