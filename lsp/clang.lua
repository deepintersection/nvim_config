-- =============================================================================
-- lsp/clangd.lua — clangd configuration (C/C++ — ESP32, RPi, embedded)
-- =============================================================================
-- Server command set via NVIM_CLANGD_PATH in the launch script.
--
-- For ESP32 projects: ESP-IDF generates compile_commands.json via CMake.
-- Run: idf.py set-target esp32s3 && idf.py build
-- clangd reads compile_commands.json from the build directory.
--
-- For RPi projects: similar CMake-based approach.
-- Set NVIM_CLANGD_PATH to the correct clangd for cross-compilation.
-- =============================================================================

---@type vim.lsp.Config
return {
  cmd = {
    vim.env.NVIM_CLANGD_PATH,
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",          -- include-what-you-use style
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
    -- utf-16 offset encoding: required for ESP-IDF projects and avoids
    -- the "multiple different client offset_encodings" warning
    "--offset-encoding=utf-16",
    -- Limit background indexing workers (important on SSH / low-power hosts)
    "--j=4",
    -- Log to file instead of stderr (reduces SSH terminal noise)
    "--log=error",
  },

  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },

  root_markers = {
    "compile_commands.json",
    "compile_flags.txt",
    "CMakeLists.txt",
    ".clangd",
    ".clang-tidy",
    ".clang-format",
    ".git",
  },

  init_options = {
    usePlaceholders    = true,
    completeUnimported = true,
    clangdFileStatus   = true,  -- show "parsing…" in status
  },

  -- clangd needs utf-16 offset encoding to avoid conflicts
  -- when multiple LSP clients are attached (e.g. clangd + ruff on mixed files)
  capabilities = {
    offsetEncoding = { "utf-16" },
  },
}
