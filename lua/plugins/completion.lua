-- =============================================================================
-- lua/plugins/completion.lua — Completion (blink.cmp v2)
-- =============================================================================
-- blink.cmp v2 is on the main branch (no stable tag yet as of May 2026).
-- V2 breaking changes vs V1:
--   · blink.lib is now a REQUIRED separate dependency (pure Lua utilities:
--     config validation, async task API, native build/download, fs, timers)
--   · Fuzzy frecency: LMDB dropped → pure Rust; DB moved to:
--       ~/.local/state/nvim/blink/cmp/frecency.dat
--   · fuzzy.use_frecency / use_proximity deprecated →
--       fuzzy.frecency.enabled / proximity (separate keys)
--   · Build: no pre-built binary download for v2 dev branch;
--       must compile from source with cargo
--   · implementation = "prefer_rust" (not "prefer_rust_with_warning")
--       since we're compiling ourselves — no warning needed
--
-- Build requirement (Gentoo):
--   rustup toolchain install stable   (already in our deps from step 4)
--   lazy.nvim runs: cargo build --release  in the plugin directory
--
-- 0.12 notes (same as v1):
--   · vim.opt.autocomplete = false  (disable 0.12 built-in)
--   · <C-S> in insert = 0.12 signature help default — NOT remapped
--   · <C-R> in insert = 0.12 literal register insert — NOT remapped
--   · <C-Space> is free (treesitter incremental selection removed step 3)
--   · On Neovim 0.11+, vim.lsp.config can skip get_lsp_capabilities()
--     but we call it for explicit capability merging
--
-- Sources: lsp path buffer snippets lazydev(lua only)
-- =============================================================================

local util = require("util")

return {

  -- ===========================================================================
  -- blink.lib — required dependency for blink.cmp v2
  -- ===========================================================================
  -- Pure Lua utility library. No build step needed.
  -- Provides: config validation, async tasks, fs, log, timers, nvim utils,
  --           native library build/download APIs (used by blink.cmp internals)
  {
    "saghen/blink.lib",
    lazy = true,  -- loaded automatically when blink.cmp requires it
  },

  -- ===========================================================================
  -- blink.cmp v2 — built from source
  -- ===========================================================================
  {
    "saghen/blink.cmp",
    branch = "main",   -- v2 is on main; no stable tag yet

    -- Build the Rust fuzzy matcher (frizbee) from source.
    -- Runs: cargo build --release  in the plugin directory.
    -- On Gentoo with rustup stable: this works out of the box.
    -- Time: ~30s on first install, instant on subsequent loads.
    -- Also available via :BlinkCmp build  (added in v2)
    build = "cargo build --release",

    dependencies = {
      "saghen/blink.lib",  -- required for v2
    },

    event = { "InsertEnter", "CmdlineEnter" },

    ---@module "blink.cmp"
    ---@type blink.cmp.Config
  opts = {
      -- Disable completion in diff buffers, fugitive, and special buffers
      enabled = function()
        local ft = vim.bo.filetype
        local bt = vim.bo.buftype
        local disabled_ft = { "fugitive", "gitcommit", "DiffviewFiles",
                               "DiffviewFileHistory", "DiffviewFileHistoryPanel" }
        for _, v in ipairs(disabled_ft) do
          if ft == v then return false end
        end
        -- Disable in non-normal buffers (terminal, quickfix, etc.)
        -- but KEEP in "" (normal) and "prompt" (telescope etc.)
        if bt ~= "" and bt ~= "prompt" then return false end
        -- Disable in diff mode
        if vim.wo.diff then return false end
        return true
      end,
 
      -- -----------------------------------------------------------------------
      -- Keymap
      -- -----------------------------------------------------------------------
      -- All mappings explicit (preset = "none") — no hidden defaults.
      -- NOT remapped: <C-S> (0.12 LSP sig help)  <C-R> (0.12 literal insert)
      -- -----------------------------------------------------------------------
      keymap = {
        preset = "none",
 
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"]     = { "hide", "fallback" },
 
        ["<Tab>"]   = { "select_next", "snippet_forward",   "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward",  "fallback" },
        ["<C-n>"]   = { "select_next", "fallback" },
        ["<C-p>"]   = { "select_prev", "fallback" },
 
        ["<CR>"]    = { "accept",           "fallback" },
        ["<C-y>"]   = { "select_and_accept" },
 
        ["<C-b>"]   = { "scroll_documentation_up",   "fallback" },
        ["<C-f>"]   = { "scroll_documentation_down", "fallback" },
 
        -- NOTE: cmdline keymap goes in the cmdline{} block below, NOT here.
        -- In v2 the keymap validator rejects keymap.cmdline as an unknown key.
      },
 
      -- -----------------------------------------------------------------------
      -- Completion behaviour
      -- -----------------------------------------------------------------------
      completion = {
        accept = {
          dot_repeat         = true,
          create_undo_point  = true,
          resolve_timeout_ms = 100,
          auto_brackets = {
            enabled = true,
            default_brackets = { "(", ")" },
            kind_resolution = {
              enabled          = true,
              blocked_filetypes = { "typescriptreact", "javascriptreact", "vue" },
            },
            semantic_token_resolution = {
              enabled          = true,
              blocked_filetypes = { "java" },
              timeout_ms       = 400,
            },
          },
        },
 
        keyword = {
          range = "prefix",   -- "prefix" | "full" — match text before cursor
        },
 
        trigger = {
          prefetch_on_insert  = not util.is_ssh,
          show_in_snippet     = true,
          show_on_keyword     = true,
          show_on_trigger_character = true,
          show_on_blocked_trigger_characters = { " ", "\n", "\t" },
          show_on_accept_on_trigger_character = true,
          show_on_insert_on_trigger_character = true,
          show_on_x_blocked_trigger_characters = { "'", '"', "(" },
        },
 
        list = {
          max_items = 200,
          selection = {
            preselect = function(ctx)
              return ctx.mode ~= "cmdline"
                and not require("blink.cmp").snippet_active({ direction = 1 })
            end,
            auto_insert = false,
          },
          cycle = {
            from_bottom = true,
            from_top     = true,
          },
        },
 
        -- Completion menu
        menu = {
          enabled     = true,
          min_width   = 15,
          max_height  = 15,
          border      = "rounded",
          winblend    = 0,
          scrollbar   = true,
 
          draw = {
            padding    = 1,
            gap        = 1,
            -- Treesitter highlighting for LSP completion items
            treesitter = { "lsp" },
 
            -- Use blink.cmp v2 built-in column components.
            -- Do NOT override components{} — v2 internal render APIs changed
            -- between v1 and v2 (label_matched_indices is now a flat int list,
            -- tailwind module removed, etc.). Built-ins handle all of this.
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "kind" },
            },
          },
        },
 
        -- Documentation popup
        documentation = {
          auto_show          = true,
          auto_show_delay_ms = util.is_ssh and 500 or 200,
          update_delay_ms    = util.is_ssh and 100 or 50,
          treesitter_highlighting = true,
          window = {
            min_width   = 10,
            max_width   = 60,
            max_height  = 20,
            border      = "rounded",
            winblend    = 0,
            scrollbar   = true,
          },
        },
 
        -- Ghost text: disabled by default (SSH performance)
        -- Enable with NVIM_GHOST_TEXT=1
        ghost_text = {
          enabled = util.env_bool("NVIM_GHOST_TEXT", false),
        },
      },
 
      -- -----------------------------------------------------------------------
      -- Signature help
      -- -----------------------------------------------------------------------
      -- Additive to 0.12 default <C-S>; does not replace it.
      signature = {
        enabled = true,
        trigger = {
          show_on_insert_on_trigger_character = true,
        },
        window = {
          min_width   = 1,
          max_width   = 100,
          max_height  = 10,
          border      = "rounded",
          winblend    = 0,
          scrollbar   = false,
          treesitter_highlighting = true,
        },
      },
 
      -- -----------------------------------------------------------------------
      -- Snippets — vim.snippet built-in (0.12)
      -- -----------------------------------------------------------------------
      snippets = {
        preset = "default",  -- uses vim.snippet; no LuaSnip needed
      },

      -- -----------------------------------------------------------------------
      -- Sources
      -- -----------------------------------------------------------------------
      sources = {
        default      = {"lazydev", "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          lua      = { "lazydev", "lsp", "path", "snippets", "buffer" },
          sql      = { "lsp", "buffer" },
          markdown = { "buffer", "path", "snippets" },
        },
 
        providers = {
          lsp = {
            name   = "LSP",
            module = "blink.cmp.sources.lsp",
            -- Filter out Text-kind items from LSP (too noisy)
            transform_items = function(_, items)
              local kinds = require("blink.cmp.types").CompletionItemKind
              return vim.tbl_filter(function(item)
                return item.kind ~= kinds.Text
              end, items)
            end,
          },
 
          path = {
            name   = "Path",
            module = "blink.cmp.sources.path",
            opts   = {
              trailing_slash               = false,
              label_trailing_slash         = true,
              show_hidden_files_by_default = false,
            },
          },
 
          buffer = {
            name   = "Buffer",
            module = "blink.cmp.sources.buffer",
            opts   = {
              -- Only normal buffers (not terminal, quickfix, etc.)
              get_bufnrs = function()
                return vim.tbl_filter(function(b)
                  return vim.bo[b].buftype == ""
                end, vim.api.nvim_list_bufs())
              end,
              -- Enable caching for performance
              use_cache = true,
            },
          },
          -- lazydev: Neovim API completions for Lua files (from plugins/lsp.lua)
          lazydev = {
            name         = "LazyDev",
            module       = "lazydev.integrations.blink",
            score_offset = 100,  -- always beat LSP for Lua Neovim API items
          },
        },
 
        -- Per-filetype minimum keyword length
        min_keyword_length = function()
          -- In large files over SSH, require at least 2 chars to trigger
          if util.is_ssh then return 2 end
          return 1
        end,
      },


      -- -----------------------------------------------------------------------
      -- Fuzzy matching — v2 API
      -- -----------------------------------------------------------------------
      -- V2 breaking change: use_frecency/use_proximity deprecated.
      -- V2 uses frecency.enabled and a separate proximity config.
      -- Frecency DB: ~/.local/state/nvim/blink/cmp/frecency.dat
      --   (moved from ~/.local/share/.../fuzzy.db in v1; LMDB dropped)
      fuzzy = {
        -- "prefer_rust": use compiled Rust binary (no warning since we built it)
        -- "lua": fallback if Rust binary fails to load
        implementation      = "rust",
      },
 
      -- -----------------------------------------------------------------------
      -- Appearance
      -- -----------------------------------------------------------------------
      appearance = {
        use_nvim_cmp_as_default = false,
        nerd_font_variant       = "mono",
      },
 
      -- -----------------------------------------------------------------------
      -- Cmdline completion
      -- -----------------------------------------------------------------------
      cmdline = {
        enabled = true,
      },

  },

    -- =========================================================================
    -- config: runs after opts is applied
    -- =========================================================================
    config = function(_, opts)
      local blink = require("blink.cmp")
      blink.setup(opts)

      -- Disable 0.12 built-in autocomplete — we use blink.cmp
      vim.opt.autocomplete = false
      

      -- Merge blink.cmp v2 LSP capabilities with our global config.
      -- Note: On Neovim 0.11+, this can be skipped when using vim.lsp.config,
      -- but we call it for explicit/correct capability merging.
      -- Called inside vim.schedule (lsp.lua) so blink is loaded first.
      vim.lsp.config("*", {
        capabilities = blink.get_lsp_capabilities(
          vim.lsp.protocol.make_client_capabilities()
        ),
      })

      -- Ghost text runtime toggle (<leader>ug)
      vim.keymap.set("n", "<leader>ug", function()
        -- V2 API for config access may differ; use pcall for safety
        local ok, cfg = pcall(require, "blink.cmp.config")
        if ok and cfg and cfg.completion and cfg.completion.ghost_text then
          cfg.completion.ghost_text.enabled = not cfg.completion.ghost_text.enabled
          vim.notify(
            "Ghost text: " .. (cfg.completion.ghost_text.enabled and "on" or "off"),
            vim.log.levels.INFO
          )
        end
      end, { desc = "Toggle completion ghost text" })
    end,
  },
}
