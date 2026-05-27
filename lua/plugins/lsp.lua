-- =============================================================================
-- lua/plugins/lsp.lua — LSP orchestration (Neovim 0.12 native)
-- =============================================================================
-- Uses vim.lsp.config() + vim.lsp.enable() — no nvim-lspconfig required.
-- Server configs live in lsp/*.lua (auto-loaded by vim.lsp.enable()).
--
-- STARTUP SAFETY:
--   All imperative LSP setup (diagnostic config, lsp.config, lsp.enable,
--   LspAttach autocmd) is wrapped in vim.schedule(). This defers execution
--   to the next event-loop tick — AFTER lazy.nvim finishes loading startup
--   plugins, but BEFORE any buffer-open event fires. This prevents any
--   early module-level code from blocking Neovim startup.
--
-- 0.12 API used:
--   vim.lsp.config("*", {...})   — global capabilities for all servers
--   vim.lsp.enable("name")       — register server for matching filetypes
--   vim.diagnostic.config({...}) — sign API (NOT vim.fn.sign_define)
--   vim.lsp.get_clients()        — NOT the removed buf_get_clients()
--   vim.diagnostic.count(bufnr)  — NOT deprecated lsp.diagnostic.*
--   vim.lsp.status()             — progress string (lualine)
--   vim.lsp.inlay_hint.enable()  — inlay hint toggle
--
-- 0.12 default LSP keymaps — DO NOT REMAP:
--   gd  K  gra  grn  grr  gri  grt  grx  gO  <C-S>(insert)
-- =============================================================================

local util = require("util")

-- =============================================================================
-- LSP setup — deferred via vim.schedule()
-- =============================================================================
-- vim.schedule() runs after the current C call stack returns to the event
-- loop. In practice: after all plugin specs load, before VimEnter / BufRead.
-- Safe for vim.lsp.enable() because LSP servers only start on filetype match,
-- which cannot happen before this scheduled function runs.
-- =============================================================================

vim.schedule(function()

  -- ---------------------------------------------------------------------------
  -- 1. Diagnostic configuration (0.12 sign API)
  -- ---------------------------------------------------------------------------
  -- The OLD vim.fn.sign_define() pattern for diagnostic signs is REMOVED
  -- in 0.12. Use vim.diagnostic.config({ signs = { text = {...} } }) instead.
  -- ---------------------------------------------------------------------------
  vim.diagnostic.config({
    underline        = true,
    update_in_insert = false,  -- no re-render on every keystroke (SSH perf)
    severity_sort    = true,
    virtual_text = {
      spacing  = 4,
      source   = "if_many",
      prefix   = "●",
      severity = { min = vim.diagnostic.severity.WARN },
    },
    -- 0.12 sign API — NOT vim.fn.sign_define()
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN]  = " ",
        [vim.diagnostic.severity.INFO]  = " ",
        [vim.diagnostic.severity.HINT]  = "󰌵 ",
      },
      numhl = {
        [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
        [vim.diagnostic.severity.WARN]  = "DiagnosticSignWarn",
      },
      linehl = {},
    },
    float = {
      focusable = false,
      style     = "minimal",
      border    = "rounded",
      source    = "if_many",
      header    = "",
      prefix    = "",
    },
  })

  -- ---------------------------------------------------------------------------
  -- 2. Global capabilities — applied to ALL servers via "*" wildcard
  -- ---------------------------------------------------------------------------
  -- blink.cmp (plugins/completion.lua) calls vim.lsp.config("*", ...) again
  -- after its own setup to merge completion capabilities. Additive — no conflict.
  -- ---------------------------------------------------------------------------
  vim.lsp.config("*", {
    capabilities = (function()
      local caps = vim.lsp.protocol.make_client_capabilities()
      -- Disable file watchers: inotify/kqueue are heavy on SSH hosts
      caps.workspace.didChangeWatchedFiles.dynamicRegistration = false
      -- Enable folding ranges
      caps.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly     = true,
      }
      return caps
    end)(),
  })

  -- ---------------------------------------------------------------------------
  -- 3. LspAttach — additional keymaps and per-buffer features
  -- ---------------------------------------------------------------------------
  -- Only keymaps NOT provided by 0.12 defaults are added here.
  -- 0.12 built-ins (do NOT remap): gd K gra grn grr gri grt grx gO <C-S>
  -- ---------------------------------------------------------------------------
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("config_lsp_attach", { clear = true }),
    callback = function(ev)
      local buf    = ev.buf
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then return end

      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer  = buf,
          silent  = true,
          noremap = true,
          desc    = desc,
        })
      end

      -- Declaration (gD) — NOT a 0.12 default (gd=definition is default)
      if client:supports_method("textDocument/declaration") then
        map("n", "gD", vim.lsp.buf.declaration, "LSP: declaration")
      end

      -- Format — fallback until conform.nvim is active for this filetype
      if client:supports_method("textDocument/formatting") then
        map({ "n", "v" }, "<leader>cf", function()
          vim.lsp.buf.format({
            bufnr      = buf,
            timeout_ms = 3000,
            filter     = function(c) return c.id == client.id end,
          })
        end, "LSP: format (fallback)")
      end

      -- Codelens refresh
      if client:supports_method("textDocument/codeLens") then
        map("n", "<leader>cl", function()
          vim.lsp.codelens.enable(true, { bufnr = buf })
        end, "LSP: refresh codelens")

        vim.api.nvim_create_autocmd(
          { "BufEnter", "BufWritePost", "InsertLeave" },
          {
            buffer   = buf,
            group    = vim.api.nvim_create_augroup(
              "config_lsp_codelens_" .. buf, { clear = true }
            ),
            callback = function()
              vim.lsp.codelens.enable(true,{ bufnr = buf })
            end,
          }
        )
      end

      -- Workspace folders
      map("n", "<leader>cwa", vim.lsp.buf.add_workspace_folder,
          "LSP: workspace add folder")
      map("n", "<leader>cwr", vim.lsp.buf.remove_workspace_folder,
          "LSP: workspace remove folder")
      map("n", "<leader>cwl", function()
        vim.notify(
          vim.inspect(vim.lsp.buf.list_workspace_folders()),
          vim.log.levels.INFO,
          { title = "LSP workspace folders" }
        )
      end, "LSP: workspace list folders")

      -- Inlay hints: enable if server supports them
      if client:supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(true, { bufnr = buf })
      end

      -- Disable semantic tokens for very large files
      if vim.api.nvim_buf_line_count(buf) > 5000 then
        client.server_capabilities.semanticTokensProvider = nil
      end

      -- Document highlight on cursor hold (local only — too noisy over SSH)
      if client:supports_method("textDocument/documentHighlight")
        and not util.is_ssh
      then
        local hl = vim.api.nvim_create_augroup(
          "config_lsp_hl_" .. buf, { clear = true }
        )
        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
          buffer = buf, group = hl,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
          buffer = buf, group = hl,
          callback = vim.lsp.buf.clear_references,
        })
      end
    end,
    desc = "LSP: attach keymaps and features",
  })

  -- ---------------------------------------------------------------------------
  -- 4. Enable servers — conditional on env vars
  -- ---------------------------------------------------------------------------
  -- vim.lsp.enable() registers an autocmd that starts the server when a
  -- buffer with a matching filetype is opened. Nothing starts at this point.
  -- ---------------------------------------------------------------------------
  local function enable_if(server, env_var)
    if util.env(env_var) then
      vim.lsp.enable(server)
    end
  end

  enable_if("pyright",       "NVIM_PYRIGHT_PATH")
  enable_if("ruff",          "NVIM_RUFF_PATH")
  enable_if("rust_analyzer", "NVIM_RUST_ANALYZER_PATH")
  enable_if("lua_ls",        "NVIM_LUA_LS_PATH")
  enable_if("clangd",        "NVIM_CLANGD_PATH")
  enable_if("bashls",        "NVIM_BASHLS_PATH")
  enable_if("taplo",         "NVIM_TAPLO_PATH")
  enable_if("jsonls",        "NVIM_JSONLS_PATH")
  enable_if("yamlls",        "NVIM_YAMLLS_PATH")

end)  -- end vim.schedule()

-- =============================================================================
-- Plugin specs
-- =============================================================================

return {
  -- lazydev.nvim — Neovim Lua API completions injected into lua_ls
  {
    "folke/lazydev.nvim",
    ft   = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim",        words = { "Snacks" } },
        { path = "lazy.nvim",          words = { "Lazy" } },
      },
      enabled = function(root_dir)
        return vim.uv.fs_stat(root_dir .. "/.lazy-dev") ~= nil
          or root_dir:find(vim.fn.stdpath("config"), 1, true) ~= nil
          or root_dir:find(vim.fn.stdpath("data"),   1, true) ~= nil
      end,
    },
  },

  -- fidget.nvim — LSP progress in the corner
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts  = {
      progress = {
        poll_rate            = util.is_ssh and 2 or 0,
        suppress_on_insert   = true,
        ignore_done_already  = true,
        ignore_empty_message = true,
        display = {
          render_limit  = 8,
          done_ttl      = 2,
          done_icon     = "✓",
          progress_icon = { pattern = "dots", period = 1 },
        },
      },
      notification = {
        override_vim_notify = false,  -- snacks handles vim.notify
        window = {
          winblend  = 0,
          border    = "none",
          zindex    = 45,
          max_width = 0,
          x_padding = 1,
          y_padding = 0,
          align     = "bottom",
          relative  = "editor",
        },
      },
    },
  },
}
