-- =============================================================================
-- lua/plugins/treesitter.lua — Treesitter (native Neovim 0.12)
-- =============================================================================
-- nvim-treesitter was ARCHIVED April 3, 2026. We use native APIs only.
--
-- Structure:
--   Module-level code  — native highlighting + folding autocmds (runs at
--                        spec-import time; NO fake dir= plugin entry)
--   return {}          — real plugin specs only
--
-- IMPORTANT: Do NOT use  dir = vim.fn.stdpath("config")  as a fake plugin.
-- That pattern causes lazy.nvim's health check to scan the entire config
-- directory, which makes :checkhealth hang with high CPU (snacks health
-- is what surfaces it, but the root cause is the fake plugin entry).
--
-- Plugins:
--   romus204/tree-sitter-manager.nvim — parser installer (:TSManager)
--   nvim-treesitter-textobjects       — text objects / movements (branch=main)
--   nvim-treesitter-context           — sticky context header
--
-- 0.12 rules:
--   - get_parser() returns nil on error → pcall / util.ts_get_parser()
--   - foldexpr = vim.treesitter.foldexpr() (public 0.12 API)
--   - Query:iter_matches "all" option removed → not used here
--
-- Environment variables:
--   NVIM_TS_AUTO_INSTALL — "1" to auto-install missing parsers (default: 0)
--
-- System requirement:
--   tree-sitter CLI: cargo install tree-sitter-cli
-- =============================================================================

local util = require("util")

local PARSERS = {
  -- 0.12 bundled (no download needed)
  --"lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "c",
  -- Languages
  --"python", "rust", "cpp", "bash",
  -- Config / data
  --"json", "json5", "yaml", "toml", "dockerfile", "ini", "sql",
  -- Docs / git
  --"rst", "gitcommit", "gitignore", "diff",
  -- Utilities
  --"regex", "comment",
}

-- =============================================================================
-- Native treesitter setup — runs at module load (before return)
-- =============================================================================
-- Registers FileType autocmds that enable highlighting and folding for every
-- buffer. This code runs once when lazy.nvim imports this spec file.
-- =============================================================================

do
  -- Highlighting + folding for every normal buffer
  vim.api.nvim_create_autocmd("FileType", {
    group   = vim.api.nvim_create_augroup("ts_native_highlight", { clear = true }),
    pattern = "*",
    callback = function(ev)
      -- Skip special buffers (terminal, quickfix, etc.)
      if vim.bo[ev.buf].buftype ~= "" then return end

      -- pcall: silently no-op if parser not installed for this filetype.
      -- 0.12: vim.treesitter.start() calls get_parser() internally and
      -- returns false (not an error) when the parser is missing.
      local ok = pcall(vim.treesitter.start, ev.buf)

      if ok then
        -- Use 0.12 public API — NOT the old "nvim_treesitter#foldexpr()" string
        vim.opt_local.foldmethod = "expr"
        vim.opt_local.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
        vim.opt_local.foldenable = false  -- keep all folds open by default
      end
    end,
    desc = "Native TS: enable highlighting and folding",
  })

  -- Stop treesitter for bigfiles.
  -- snacks.bigfile (plugins/ui.lua) sets ft=bigfile for large files.
  -- This autocmd ensures TS is stopped and folding falls back to manual.
  vim.api.nvim_create_autocmd("FileType", {
    group   = vim.api.nvim_create_augroup("ts_native_bigfile", { clear = true }),
    pattern = "bigfile",
    callback = function(ev)
      pcall(vim.treesitter.stop, ev.buf)
      vim.opt_local.foldmethod = "manual"
    end,
    desc = "Native TS: stop for bigfiles",
  })

  -- <leader>uf — toggle treesitter folding in the current buffer
  vim.keymap.set("n", "<leader>uf", function()
    if vim.opt_local.foldmethod:get() == "expr" then
      vim.opt_local.foldmethod = "manual"
      vim.notify("Folding: manual", vim.log.levels.INFO)
    else
      -- 0.12: guard get_parser() nil return
      if not util.ts_get_parser(0) then
        vim.notify("No treesitter parser for this filetype", vim.log.levels.WARN)
        return
      end
      vim.opt_local.foldmethod = "expr"
      vim.opt_local.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
      vim.notify("Folding: treesitter", vim.log.levels.INFO)
    end
  end, { desc = "Toggle treesitter folding" })
end

-- =============================================================================
-- Plugin specs
-- =============================================================================

return {

  -- ===========================================================================
  -- 1. Parser installer — tree-sitter-manager.nvim
  -- ===========================================================================
  -- cmd-only: NEVER lazy=false. ensure_installed with lazy=false calls the
  -- tree-sitter CLI for each parser synchronously at startup — hangs if the
  -- binary is missing or slow to respond.
  --
  -- Install parsers after first launch:
  --   :TSManager  (i=install  x=remove  u=update  q=quit)
  --
  -- Or directly in shell:
  --   tree-sitter grammar install python rust cpp bash
  --
  -- Requires tree-sitter CLI:  cargo install tree-sitter-cli
  {
    "romus204/tree-sitter-manager.nvim",
    cmd  = { "TSManager" },
    opts = {
      -- No ensure_installed — parsers are managed manually via :TSManager
      auto_install = false,
      highlight    = false,  -- FileType autocmd above handles this
      border       = "rounded",
    },
  },

  -- ===========================================================================
  -- 2. nvim-treesitter-textobjects (branch=main, standalone — no nvim-ts dep)
  -- ===========================================================================
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event  = { "BufReadPost", "BufNewFile" },

    -- init: runs before config, before any ftplugin fires.
    -- Disables only KEY MAPPINGS in built-in ftplugins (not indent, syntax, etc.)
    init = function()
      vim.g.no_plugin_maps = true
    end,

    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
          selection_modes = {
            ["@function.outer"]    = "V",
            ["@class.outer"]       = "V",
            ["@loop.outer"]        = "V",
            ["@conditional.outer"] = "V",
            ["@parameter.outer"]   = "v",
            ["@assignment.outer"]  = "v",
          },
          include_surrounding_whitespace = false,
        },
      })

      -- Aliases
      local sel  = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")

      local function s(query, group)
        return function()
          sel.select_textobject(query, group or "textobjects")
        end
      end

      -- -----------------------------------------------------------------------
      -- Text object SELECT (x=visual, o=operator-pending)
      -- -----------------------------------------------------------------------
      local to_maps = {
        { "af", "@function.outer"    }, { "if", "@function.inner"    },
        { "ac", "@class.outer"       }, { "ic", "@class.inner"       },
        { "aa", "@parameter.outer"   }, { "ia", "@parameter.inner"   },
        { "ao", "@loop.outer"        }, { "io", "@loop.inner"        },
        { "ai", "@conditional.outer" }, { "ii", "@conditional.inner" },
        { "a=", "@assignment.outer"  }, { "i=", "@assignment.inner"  },
        { "ar", "@return.outer"      }, { "ir", "@return.inner"      },
      }
      for _, m in ipairs(to_maps) do
        vim.keymap.set({ "x", "o" }, m[1], s(m[2]),
          { desc = "TS: " .. m[2], silent = true })
      end

      -- Scope (uses "locals" query group)
      vim.keymap.set({ "x", "o" }, "as", function()
        sel.select_textobject("@local.scope", "locals")
      end, { desc = "TS: scope", silent = true })

      -- -----------------------------------------------------------------------
      -- MOVEMENT (n/x/o)
      -- Conflict map:
      --   ]c/[c → gitsigns    ]d/[d → 0.12 diagnostics
      --   ]l/[l → loclist     ]q/[q → quickfix    ]t/[t → tabs
      -- Safe: ]f [f ]F [F ]C [C ]E [E ]a [a ]o [o ]i [i
      -- -----------------------------------------------------------------------
      local function mv(dir, finish, query)
        local method = (dir == "next" and "goto_next_" or "goto_previous_")
                    .. (finish == "end" and "end" or "start")
        return function()
          move[method](query, "textobjects")
        end
      end

      local move_maps = {
        { "]f", "next", "start", "@function.start"    },
        { "]C", "next", "start", "@class.start"       },
        { "]a", "next", "start", "@parameter.inner"   },
        { "]o", "next", "start", "@loop.outer"        },
        { "]i", "next", "start", "@conditional.outer" },
        { "]F", "next", "end",   "@function.end"      },
        { "]E", "next", "end",   "@class.end"         },
        { "[f", "prev", "start", "@function.start"    },
        { "[C", "prev", "start", "@class.start"       },
        { "[a", "prev", "start", "@parameter.inner"   },
        { "[o", "prev", "start", "@loop.outer"        },
        { "[i", "prev", "start", "@conditional.outer" },
        { "[F", "prev", "end",   "@function.end"      },
        { "[E", "prev", "end",   "@class.end"         },
      }
      for _, m in ipairs(move_maps) do
        vim.keymap.set({ "n", "x", "o" }, m[1], mv(m[2], m[3], m[4]),
          { desc = ("TS: %s %s %s"):format(m[2], m[3], m[4]), silent = true })
      end

      -- -----------------------------------------------------------------------
      -- SWAP
      -- -----------------------------------------------------------------------
      vim.keymap.set("n", "<leader>csn", function()
        swap.swap_next("@parameter.inner", "textobjects")
      end, { desc = "TS: swap next argument", silent = true })

      vim.keymap.set("n", "<leader>csp", function()
        swap.swap_previous("@parameter.inner", "textobjects")
      end, { desc = "TS: swap prev argument", silent = true })

      -- -----------------------------------------------------------------------
      -- Repeatable ; and , for TS moves
      -- -----------------------------------------------------------------------
      local ok, rep = pcall(require, "nvim-treesitter-textobjects.repeatable_move")
      if ok then
        vim.keymap.set({ "n", "x", "o" }, ";", rep.repeat_last_move_next,
          { desc = "TS: repeat move next" })
        vim.keymap.set({ "n", "x", "o" }, ",", rep.repeat_last_move_previous,
          { desc = "TS: repeat move prev" })
        vim.keymap.set({ "n", "x", "o" }, "f", rep.builtin_f_expr, { expr = true })
        vim.keymap.set({ "n", "x", "o" }, "F", rep.builtin_F_expr, { expr = true })
        vim.keymap.set({ "n", "x", "o" }, "t", rep.builtin_t_expr, { expr = true })
        vim.keymap.set({ "n", "x", "o" }, "T", rep.builtin_T_expr, { expr = true })
      end
    end,
  },

  -- ===========================================================================
  -- 3. nvim-treesitter-context — sticky context header (not archived)
  -- ===========================================================================
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts  = {
      enable              = true,
      max_lines           = 4,
      min_window_height   = 20,
      line_numbers        = true,
      multiline_threshold = 1,
      trim_scope          = "outer",
      mode                = "cursor",
      separator           = nil,
      zindex              = 20,
      on_attach = function(buf)
        local disabled_ft = { "help", "terminal", "lazy", "toggleterm", "qf", "bigfile" }
        local ft = vim.bo[buf].filetype
        for _, v in ipairs(disabled_ft) do
          if ft == v then return false end
        end
        -- 0.12: guard get_parser() nil
        return util.ts_get_parser(buf) ~= nil
      end,
    },
    config = function(_, opts)
      require("treesitter-context").setup(opts)

      vim.keymap.set("n", "<leader>uc", function()
        require("treesitter-context").go_to_context(vim.v.count1)
      end, { desc = "Jump to treesitter context" })

      vim.keymap.set("n", "<leader>uC", function()
        require("treesitter-context").toggle()
      end, { desc = "Toggle treesitter context" })
    end,
  },
}
