-- =============================================================================
-- lua/plugins/lang/rust.lua — Rust
-- =============================================================================
-- Covers:
--   · Rust filetype options + buffer-local Cargo keymaps
--   · crates.nvim  — Cargo.toml crate version display + blink.cmp source
--   · neotest-rust — cargo test adapter (extends neotest from python.lua)
--
-- LSP (rust-analyzer) configured in lsp/rust_analyzer.lua (step 4).
-- Formatter (rustfmt) configured in plugins/editor.lua (conform, step 5).
-- DAP (codelldb) configured in plugins/dap.lua (step 10).
-- toggleterm already loaded from plugins/lang/python.lua (step 8).
--
-- Keymaps (buffer-local, Rust files only — <leader>l language group):
--   <leader>lb   cargo build
--   <leader>lr   cargo run
--   <leader>lR   cargo run --release
--   <leader>lc   cargo check
--   <leader>lC   cargo clippy -- -D warnings
--   <leader>lt   cargo test (all)
--   <leader>ld   cargo doc --open
--   <leader>la   cargo add <crate>  (interactive prompt)
--   <leader>lu   cargo update
--
-- Environment variables:
--   NVIM_RUST_ANALYZER_PATH  — rust-analyzer binary (step 4)
--   NVIM_RUSTFMT_PATH        — rustfmt binary (step 5)
-- =============================================================================

local util = require("util")

-- =============================================================================
-- Module-level: Rust filetype options + buffer-local keymaps
-- =============================================================================

do
  vim.api.nvim_create_autocmd("FileType", {
    group   = vim.api.nvim_create_augroup("config_rust_ft", { clear = true }),
    pattern = "rust",
    callback = function(ev)
      local buf = ev.buf

      -- Rust style guide: 100 char limit (rustfmt default)
      vim.opt_local.textwidth   = 100
      vim.opt_local.colorcolumn = "100,120"
      -- Rust files use 4-space indent (already global default)
      -- Disable smartindent — rust treesitter handles indentation
      vim.opt_local.smartindent = false

      -- -----------------------------------------------------------------------
      -- Buffer-local Cargo keymaps
      -- All run in a toggleterm float terminal. If toggleterm is not loaded
      -- yet, fall back to :terminal.
      -- -----------------------------------------------------------------------
      local function cargo(args, title)
        return function()
          local cmd = "cargo " .. args
          local ok, Terminal = pcall(
            function() return require("toggleterm.terminal").Terminal end
          )
          if ok then
            Terminal:new({
              cmd        = cmd,
              direction  = "float",
              float_opts = {
                border = "rounded",
                title  = " " .. (title or cmd) .. " ",
              },
              close_on_exit = false,  -- keep open to read output
              on_open = function(_) vim.cmd("startinsert!") end,
            }):toggle()
          else
            vim.cmd("split | terminal " .. cmd)
          end
        end
      end

      local map = function(lhs, fn, desc)
        vim.keymap.set("n", lhs, fn, {
          buffer  = buf,
          silent  = true,
          noremap = true,
          desc    = desc,
        })
      end

      map("<leader>lb", cargo("build",                "cargo build"),       "Rust: cargo build")
      map("<leader>lr", cargo("run",                  "cargo run"),         "Rust: cargo run")
      map("<leader>lR", cargo("run --release",        "cargo run release"), "Rust: cargo run --release")
      map("<leader>lc", cargo("check",                "cargo check"),       "Rust: cargo check")
      map("<leader>lC", cargo("clippy -- -D warnings","cargo clippy"),      "Rust: cargo clippy")
      map("<leader>lt", cargo("test",                 "cargo test"),        "Rust: cargo test")
      map("<leader>ld", cargo("doc --open",           "cargo doc"),         "Rust: cargo doc --open")
      map("<leader>lu", cargo("update",               "cargo update"),      "Rust: cargo update")

      -- cargo add: prompt for crate name
      map("<leader>la", function()
        vim.ui.input({ prompt = "cargo add: " }, function(crate)
          if crate and crate ~= "" then
            cargo("add " .. crate, "cargo add " .. crate)()
          end
        end)
      end, "Rust: cargo add <crate>")

      -- Open Cargo.toml for the current workspace
      map("<leader>lm", function()
        local cargo_toml = vim.fn.findfile("Cargo.toml", vim.fn.getcwd() .. ";")
        if cargo_toml ~= "" then
          vim.cmd("edit " .. cargo_toml)
        else
          vim.notify("Cargo.toml not found", vim.log.levels.WARN)
        end
      end, "Rust: open Cargo.toml")
    end,
    desc = "Rust: filetype options and Cargo keymaps",
  })
end

-- =============================================================================
-- Plugin specs
-- =============================================================================

return {

  -- ===========================================================================
  -- 1. crates.nvim — Cargo.toml crate version display
  -- ===========================================================================
  -- Shows the latest version, features, and dependencies of crates in
  -- Cargo.toml inline as virtual text and in a popup.
  -- Integrates with blink.cmp as a completion source for crate names/versions.
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },

    opts = {
      -- Show version information as virtual text in Cargo.toml
      inline_hints = {
        enabled = true,
      },

      -- Popup for crate details
      popup = {
        autofocus = false,
        border    = "rounded",
        style     = "minimal",
        show_version_date    = true,
        show_dependency_version = true,
        max_height = 30,
        min_width  = 20,
        padding    = 1,
        text = {
          title        = "  %s",
          version      = "  %s",
          prerelease   = "  %s",
          yanked       = "  %s",
          feature      = "  %s",
          date         = "  %s",
          optional     = "  %s",
          description  = "  %s",
          created_at   = "  %s",
          documentation = "  %s",
          homepage      = "  %s",
          repository    = "  %s",
        },
      },

      -- Source for blink.cmp (crate name and version completion in Cargo.toml)
      completion = {
        crates = {
          enabled = true,
          max_results = 8,
          min_chars   = 3,
        },
      },

      -- LSP integration (code actions for crates)
      lsp = {
        enabled    = true,
        on_attach  = function(_, _) end,  -- handled by our LspAttach autocmd
        actions    = true,
        completion = true,
        hover      = true,
      },
    },

    config = function(_, opts)
      require("crates").setup(opts)

      -- Add crates.nvim as a blink.cmp source for Cargo.toml files
      -- Extend blink.cmp sources without re-calling blink.setup()
      -- (blink.cmp is already set up; crates provides a get_completions API)
      vim.api.nvim_create_autocmd("FileType", {
        group   = vim.api.nvim_create_augroup("config_crates_blink", { clear = true }),
        pattern = "toml",
        callback = function()
          -- crates.nvim registers itself with blink.cmp via the lsp.completion option
          -- No additional setup needed when lsp.completion = true
        end,
      })

      -- Buffer-local keymaps for Cargo.toml
      vim.api.nvim_create_autocmd("BufRead", {
        group   = vim.api.nvim_create_augroup("config_crates_keymaps", { clear = true }),
        pattern = "Cargo.toml",
        callback = function(ev)
          local crates = require("crates")
          local buf = ev.buf
          local map = function(lhs, fn, desc)
            vim.keymap.set("n", lhs, fn, {
              buffer  = buf,
              silent  = true,
              noremap = true,
              desc    = desc,
            })
          end

          map("K",           crates.show_popup,              "Crates: show info")
          map("<leader>cv",  crates.show_versions_popup,     "Crates: show versions")
          map("<leader>cf",  crates.show_features_popup,     "Crates: show features")
          map("<leader>cd",  crates.show_dependencies_popup, "Crates: show dependencies")
          map("<leader>cu",  crates.upgrade_crate,           "Crates: upgrade")
          map("<leader>cU",  crates.upgrade_all_crates,      "Crates: upgrade all")
          map("<leader>ca",  crates.update_crate,            "Crates: update to newest compat")
          map("<leader>cA",  crates.update_all_crates,       "Crates: update all")
          map("<leader>cx",  crates.expand_plain_crate_to_inline_table, "Crates: expand inline")
          map("<leader>cX",  crates.extract_crate_into_table, "Crates: extract to table")
          map("<leader>ch",  crates.open_homepage,           "Crates: open homepage")
          map("<leader>cr",  crates.open_repository,         "Crates: open repository")
          map("<leader>co",  crates.open_documentation,      "Crates: open docs.rs")
          map("<leader>cc",  crates.open_crates_io,          "Crates: open crates.io")

          -- Visual mode: operate on selection
          vim.keymap.set("v", "<leader>cu", crates.upgrade_crates,
            { buffer = buf, silent = true, desc = "Crates: upgrade selected" })
          vim.keymap.set("v", "<leader>ca", crates.update_crates,
            { buffer = buf, silent = true, desc = "Crates: update selected" })
        end,
        desc = "Crates: buffer-local keymaps for Cargo.toml",
      })
    end,
  },

  -- ===========================================================================
  -- 2. neotest-rust — cargo test adapter
  -- ===========================================================================
  -- Extends neotest (already configured in plugins/lang/python.lua) with a
  -- Rust adapter using cargo test / cargo nextest.
  --
  -- lazy.nvim merge pattern:
  --   python.lua defines neotest with opts={adapters={}} + config function
  --   rust.lua adds to opts.adapters via opts function → merged before config runs
  --   Result: config sees adapters = [python_adapter, rust_adapter]
  --
  -- Optional but recommended: cargo install cargo-nextest
  --   nextest provides better output parsing and parallel test execution.
  {
    "nvim-neotest/neotest",
    dependencies = { "rouge8/neotest-rust" },

    -- opts as function: receives merged opts from python.lua, adds rust adapter
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, require("neotest-rust")({
        -- Use cargo nextest if available (faster, better output), else cargo test
        args         = { "--no-fail-fast" },
        dap_adapter  = "codelldb",  -- referenced in dap.lua step 10
      }))
      return opts
    end,
  },
}
