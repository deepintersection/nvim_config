-- =============================================================================
-- lua/plugins/editor.lua — Editor tooling
-- =============================================================================
-- NOTE: lazydev.nvim (Neovim Lua dev completions) is configured in
--       lua/plugins/lsp.lua — search for "lazydev" there.
--
-- Plugins:
--   conform.nvim      — formatting  (<leader>cf, optional format-on-save)
--   nvim-lint         — linting     (shellcheck, hadolint; ruff LSP covers Python)
--   fzf-lua           — fuzzy finder (<leader>f group)
--   mini.pairs        — auto-close pairs () [] {} "" ''
--   mini.surround     — surround operations sa/sd/sr/sf/sF
--   oil.nvim          — directory-as-buffer file manager (SSH-friendly)
--
-- Environment variables:
--   NVIM_FORMAT_ON_SAVE     — "1" to format on BufWritePre (default: 0)
--   NVIM_RUFF_PATH          — ruff binary (ruff_format + ruff_organize_imports)
--   NVIM_BLACK_PATH         — black binary (fallback if ruff not set)
--   NVIM_ISORT_PATH         — isort binary (used with black)
--   NVIM_STYLUA_PATH        — stylua binary (Lua)
--   NVIM_RUSTFMT_PATH       — rustfmt binary (Rust)
--   NVIM_SHFMT_PATH         — shfmt binary (Bash/sh)
--   NVIM_CLANG_FORMAT_PATH  — clang-format binary (C/C++)
--   NVIM_PRETTIER_PATH      — prettier binary (JSON/YAML/Markdown/CSS/HTML)
--   NVIM_SHELLCHECK_PATH    — shellcheck binary (lint: Bash/sh)
--   NVIM_HADOLINT_PATH      — hadolint binary (lint: Dockerfile)
--   NVIM_FZF_PATH           — fzf binary path (default: "fzf" from PATH)
-- =============================================================================

local util = require("util")

return {

  -- ===========================================================================
  -- 1. conform.nvim — Formatting
  -- ===========================================================================
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd   = { "ConformInfo", "Format" },

    opts = function()
      -- -----------------------------------------------------------------------
      -- Build formatter list per filetype based on available env vars.
      -- Conform only runs a formatter if the binary is found — but being
      -- explicit here avoids silent no-ops on misconfigured machines.
      -- -----------------------------------------------------------------------

      -- Python: prefer rff (format + imports in one tool) over black + isort
      local python_fmts = {}
      if util.env("NVIM_RUFF_PATH") then
        python_fmts = { "ruff_format", "ruff_organize_imports" }
      elseif util.env("NVIM_BLACK_PATH") then
        python_fmts = util.env("NVIM_ISORT_PATH")
          and { "isort", "black" }
          or  { "black" }
      end

      local rust_fmts   = util.env("NVIM_RUSTFMT_PATH")       and { "rustfmt" }       or {}
      local lua_fmts    = util.env("NVIM_STYLUA_PATH")        and { "stylua" }        or {}
      local c_fmts      = util.env("NVIM_CLANG_FORMAT_PATH")  and { "clang_format" }  or {}
      local sh_fmts     = util.env("NVIM_SHFMT_PATH")         and { "shfmt" }         or {}
      local prettier_fmts = util.env("NVIM_PRETTIER_PATH")
        and { "prettier" } or {}

      -- TOML: use taplo if NVIM_TAPLO_PATH is set (same var as LSP server)
      local toml_fmts   = util.env("NVIM_TAPLO_PATH")         and { "taplo" }         or {}

      return {
        -- Default formatter timeout (ms). Raise for slow formatters over SSH.
        default_format_opts = {
          timeout_ms  = 3000,
          lsp_format  = "fallback",  -- use LSP format if no conform formatter
        },

        formatters_by_ft = {
          python     = python_fmts,
          rust       = rust_fmts,
          lua        = lua_fmts,
          c          = c_fmts,
          cpp        = c_fmts,
          sh         = sh_fmts,
          bash       = sh_fmts,
          zsh        = sh_fmts,
          toml       = toml_fmts,
          json       = prettier_fmts,
          jsonc      = prettier_fmts,
          yaml       = prettier_fmts,
          markdown   = prettier_fmts,
          html       = prettier_fmts,
          css        = prettier_fmts,
          -- Fallback: try LSP formatter for any unlisted filetype
          ["_"]      = { "trim_whitespace" },
        },

        -- Format on save — opt-in via NVIM_FORMAT_ON_SAVE=1
        -- Keep off by default: formatting can be slow over SSH
        format_on_save = util.env_bool("NVIM_FORMAT_ON_SAVE", false)
          and {
            timeout_ms = 2000,
            lsp_format = "fallback",
          }
          or nil,

        -- -----------------------------------------------------------------------
        -- Formatter overrides — point each to its env-var binary
        -- Only override if env var is set; otherwise conform uses PATH lookup
        -- -----------------------------------------------------------------------
        formatters = {
          ruff_format = {
            command = util.env("NVIM_RUFF_PATH") or "ruff",
          },
          ruff_organize_imports = {
            command = util.env("NVIM_RUFF_PATH") or "ruff",
          },
          black = {
            command = util.env("NVIM_BLACK_PATH") or "black",
          },
          isort = {
            command = util.env("NVIM_ISORT_PATH") or "isort",
          },
          stylua = {
            command = util.env("NVIM_STYLUA_PATH") or "stylua",
          },
          rustfmt = {
            command = util.env("NVIM_RUSTFMT_PATH") or "rustfmt",
          },
          clang_format = {
            command = util.env("NVIM_CLANG_FORMAT_PATH") or "clang-format",
          },
          shfmt = {
            command = util.env("NVIM_SHFMT_PATH") or "shfmt",
            args    = { "-i", "4", "-ci", "-" },  -- 4-space indent, switch indent
          },
          prettier = {
            command = util.env("NVIM_PRETTIER_PATH") or "prettier",
          },
          taplo = {
            command = util.env("NVIM_TAPLO_PATH") or "taplo",
          },
        },
      }
    end,

    config = function(_, opts)
      require("conform").setup(opts)

      -- -----------------------------------------------------------------------
      -- <leader>cf — Format buffer / selection
      -- Overrides the LSP fallback keymap set in plugins/lsp.lua LspAttach.
      -- Works in normal mode (whole buffer) and visual mode (selection).
      -- -----------------------------------------------------------------------
      vim.keymap.set({ "n", "v" }, "<leader>cf", function()
        local conform = require("conform")
        conform.format({
          bufnr      = vim.api.nvim_get_current_buf(),
          timeout_ms = 3000,
          lsp_format = "fallback",
          -- In visual mode, format only the selected range
          range = (function()
            local mode = vim.fn.mode()
            if mode == "v" or mode == "V" then
              local s = vim.fn.getpos("v")
              local e = vim.fn.getpos(".")
              return {
                start = { s[2], s[3] - 1 },
                ["end"] = { e[2], e[3] - 1 },
              }
            end
          end)(),
        })
      end, { desc = "Format buffer / selection" })

      -- <leader>cF — Toggle format-on-save for current buffer
      vim.keymap.set("n", "<leader>cF", function()
        local conform = require("conform")
        -- Toggle by setting/clearing buffer-local format_on_save
        if vim.b.conform_format_on_save == nil then
          vim.b.conform_format_on_save = not util.env_bool("NVIM_FORMAT_ON_SAVE", false)
        else
          vim.b.conform_format_on_save = not vim.b.conform_format_on_save
        end
        local state = vim.b.conform_format_on_save and "on" or "off"
        vim.notify("Format on save: " .. state, vim.log.levels.INFO)
      end, { desc = "Toggle format on save (buffer)" })

      -- User command for explicit format
      vim.api.nvim_create_user_command("Format", function(args)
        local range = nil
        if args.count ~= -1 then
          local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
          range = {
            start = { args.line1, 0 },
            ["end"] = { args.line2, #end_line },
          }
        end
        require("conform").format({ async = true, lsp_format = "fallback", range = range })
      end, { range = true })
    end,
  },

  -- ===========================================================================
  -- 2. nvim-lint — Linting
  -- ===========================================================================
  -- Scope: only linters not already covered by LSP servers.
  --   Python  → ruff LSP (step 4) + pyright LSP (step 4) — skip here
  --   Rust    → rust-analyzer LSP — skip here
  --   Lua     → lua_ls LSP — skip here
  --   Bash    → shellcheck (LSP bashls also uses it, but lint gives inline marks)
  --   Docker  → hadolint
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost" },

    config = function()
      local lint = require("lint")

      -- -----------------------------------------------------------------------
      -- Linter assignments — only activate if binary env var is set
      -- -----------------------------------------------------------------------
      lint.linters_by_ft = {}

      if util.env("NVIM_SHELLCHECK_PATH") then
        lint.linters_by_ft.sh   = { "shellcheck" }
        lint.linters_by_ft.bash = { "shellcheck" }
      end

      if util.env("NVIM_HADOLINT_PATH") then
        lint.linters_by_ft.dockerfile = { "hadolint" }
      end

      -- -----------------------------------------------------------------------
      -- Override linter binary paths from env vars
      -- -----------------------------------------------------------------------
      if util.env("NVIM_SHELLCHECK_PATH") then
        lint.linters.shellcheck.cmd = vim.env.NVIM_SHELLCHECK_PATH
      end
      if util.env("NVIM_HADOLINT_PATH") then
        lint.linters.hadolint.cmd = vim.env.NVIM_HADOLINT_PATH
      end

      -- -----------------------------------------------------------------------
      -- Trigger linting on write and buffer enter
      -- -----------------------------------------------------------------------
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
        group    = vim.api.nvim_create_augroup("config_nvim_lint", { clear = true }),
        callback = function()
          -- Only lint if there's an assigned linter for this filetype
          local ft = vim.bo.filetype
          if lint.linters_by_ft[ft] and #lint.linters_by_ft[ft] > 0 then
            lint.try_lint()
          end
        end,
        desc = "nvim-lint: run on write/enter",
      })

      -- <leader>ll — manual lint trigger
      vim.keymap.set("n", "<leader>ll", function()
        require("lint").try_lint()
      end, { desc = "Lint current buffer" })
    end,
  },

  -- ===========================================================================
  -- 3. fzf-lua — Fuzzy finder
  -- ===========================================================================
  -- fzf must be installed on the system: https://github.com/junegunn/fzf
  -- SSH-first design: fzf is a terminal tool, works perfectly over SSH.
  {
    "ibhagwan/fzf-lua",
    cmd   = "FzfLua",
    event = "VeryLazy",
    dependencies = { "echasnovski/mini.icons" },

    opts = function()
      local fzf_lua = require("fzf-lua")

      return {
        -- fzf binary path (defaults to "fzf" from PATH)
        fzf_bin = util.env("NVIM_FZF_PATH") or "fzf",

        -- Global winopts
        winopts = {
          height  = 0.85,
          width   = 0.85,
          row     = 0.35,
          col     = 0.50,
          border  = "rounded",
          preview = {
            border      = "border",
            scrollbar   = "float",
            -- Narrower preview over SSH to reduce data transfer
            layout      = util.is_ssh and "vertical" or "horizontal",
            vertical    = "up:45%",
            horizontal  = "right:50%",
            -- Use bat for syntax-highlighted previews if available
            default     = "bat",
          },
        },

        -- Key bindings inside fzf
        keymap = {
          builtin = {
            ["<C-f>"]   = "preview-page-down",
            ["<C-b>"]   = "preview-page-up",
            ["<C-d>"]   = "preview-half-page-down",
            ["<C-u>"]   = "preview-half-page-up",
            ["<F1>"]    = "toggle-help",
            ["<F2>"]    = "toggle-fullscreen",
            ["<F3>"]    = "toggle-preview-wrap",
            ["<F4>"]    = "toggle-preview",
          },
          fzf = {
            ["ctrl-q"]  = "select-all+accept",  -- send all to quickfix
            ["ctrl-a"]  = "select-all",
          },
        },

        actions = {
          files = {
            ["default"] = fzf_lua.actions.file_edit_or_qf,
            ["ctrl-s"]  = fzf_lua.actions.file_split,
            ["ctrl-v"]  = fzf_lua.actions.file_vsplit,
            ["ctrl-t"]  = fzf_lua.actions.file_tabedit,
            ["ctrl-q"]  = fzf_lua.actions.file_sel_to_qf,
          },
        },

        -- Source: files
        files = {
          prompt       = "Files❯ ",
          git_icons    = true,
          file_icons   = true,
          color_icons  = true,
          -- Respect .gitignore; faster over SSH
          cmd          = "rg --files --hidden --follow --glob '!.git'",
        },

        -- Source: live grep
        grep = {
          prompt       = "Grep❯ ",
          input_prompt = "Grep For❯ ",
          -- rg flags: hidden files, follow symlinks, smart case
          rg_opts = table.concat({
            "--column", "--line-number", "--no-heading",
            "--color=always", "--smart-case",
            "--hidden", "--glob=!.git",
          }, " "),
        },

        -- Source: buffers
        buffers = {
          prompt      = "Buffers❯ ",
          file_icons  = true,
          color_icons = true,
          sort_lastused = true,
        },

        -- Source: LSP
        lsp = {
          prompt_postfix = "❯ ",
          -- Jump directly if only one result (avoids unnecessary fzf window)
          jump_to_single_result = true,
          -- Show icons and filename in results
          includeDeclaration = true,
        },

        -- Source: diagnostics
        diagnostics = {
          prompt      = "Diagnostics❯ ",
          file_icons  = true,
          color_icons = true,
        },
      }
    end,

    config = function(_, opts)
      require("fzf-lua").setup(opts)

      -- Optionally replace vim.ui.select with fzf-lua (code actions etc.)
      require("fzf-lua").register_ui_select()

      -- -----------------------------------------------------------------------
      -- Keymaps — <leader>f group
      -- -----------------------------------------------------------------------
      local fzf = require("fzf-lua")
      local map = function(lhs, fn, desc)
        vim.keymap.set("n", lhs, fn, { desc = desc, silent = true })
      end

      -- Files
      map("<leader>ff", fzf.files,        "Find: files")
      map("<leader>fr", fzf.oldfiles,     "Find: recent files")
      map("<leader>f.", function()        -- config files
        fzf.files({ cwd = vim.fn.stdpath("config") })
      end, "Find: nvim config files")

      -- Search / grep
      map("<leader>fg", fzf.live_grep,              "Find: live grep")
      map("<leader>fG", fzf.grep_cword,             "Find: grep word under cursor")
      map("<leader>f/", fzf.grep_curbuf,            "Find: grep current buffer")
      map("<leader>fw", fzf.grep_cword,             "Find: word under cursor")

      -- Buffers & windows
      map("<leader>fb", fzf.buffers,                "Find: buffers")
      map("<leader>fj", fzf.jumps,                  "Find: jump list")

      -- LSP
      map("<leader>fs", fzf.lsp_document_symbols,   "Find: LSP document symbols")
      map("<leader>fS", fzf.lsp_workspace_symbols,  "Find: LSP workspace symbols")
      map("<leader>fd", fzf.diagnostics_document,   "Find: diagnostics (buffer)")
      map("<leader>fD", fzf.diagnostics_workspace,  "Find: diagnostics (workspace)")

      -- Vim / help
      map("<leader>fh", fzf.help_tags,              "Find: help tags")
      map("<leader>fk", fzf.keymaps,                "Find: keymaps")
      map("<leader>fc", fzf.command_history,        "Find: command history")
      map("<leader>fC", fzf.commands,               "Find: commands")
      map("<leader>fm", fzf.marks,                  "Find: marks")

      -- Quickfix & location lists
      map("<leader>fq", fzf.quickfix,               "Find: quickfix list")
      map("<leader>fQ", fzf.loclist,                "Find: location list")

      -- Git (basic — more in plugins/git.lua step 7)
      map("<leader>fgb", fzf.git_branches,          "Find: git branches")
      map("<leader>fgc", fzf.git_commits,           "Find: git commits")
      map("<leader>fgf", fzf.git_files,             "Find: git files")

      -- Visual mode: grep selection
      vim.keymap.set("v", "<leader>fg", fzf.grep_visual,
        { desc = "Find: grep visual selection", silent = true })
    end,
  },

  -- ===========================================================================
  -- 4. mini.pairs — Auto-close pairs
  -- ===========================================================================
  --{
  --  "echasnovski/mini.pairs",
  --  event = "InsertEnter",
  --  opts  = {
  --    modes = { insert = true, command = false, terminal = false },

  --    -- Pairs to auto-close
  --    mappings = {
  --      ["("]  = { action = "open",  pair = "()",  neigh_pattern = "[^\\]." },
  --      ["["]  = { action = "open",  pair = "[]",  neigh_pattern = "[^\\]." },
  --      ["{"]  = { action = "open",  pair = "{}",  neigh_pattern = "[^\\]." },
  --      [")"]  = { action = "close", pair = "()",  neigh_pattern = "[^\\]." },
  --      ["]"]  = { action = "close", pair = "[]",  neigh_pattern = "[^\\]." },
  --      ["}"]  = { action = "close", pair = "{}",  neigh_pattern = "[^\\]." },
  --      ['"']  = { action = "closeopen", pair = '""', neigh_pattern = "[^\\].",
  --                 register = { cr = false } },
  --      ["'"]  = { action = "closeopen", pair = "''", neigh_pattern = "[^%a\\].",
  --                 register = { cr = false } },
  --      ["`"]  = { action = "closeopen", pair = "``", neigh_pattern = "[^\\].",
  --                 register = { cr = false } },
  --    },
  --  },
  --},

  -- ===========================================================================
  -- 5. mini.surround — Surround operations
  -- ===========================================================================
  -- Default prefix: s
  --   sa{motion}{char} — add surround     (e.g. saiw" → surround word with ")
  --   sd{char}         — delete surround  (e.g. sd" → remove surrounding ")
  --   sr{old}{new}     — replace surround (e.g. sr"' → change " to ')
  --   sf{char}         — find right surround
  --   sF{char}         — find left surround
  --   sh{char}         — highlight surround
  --   sn               — update n_lines
  --
  -- Conflict check: 's' prefix is free — no 0.12 default or our keymaps use it
  -- as an operator prefix. Bare 's' (substitute char = cl) still works.
  -- {
  --   "echasnovski/mini.surround",
  --   keys = {
  --     { "sa", mode = { "n", "v" }, desc = "Surround: add" },
  --     { "sd",                      desc = "Surround: delete" },
  --     { "sr",                      desc = "Surround: replace" },
  --     { "sf",                      desc = "Surround: find right" },
  --     { "sF",                      desc = "Surround: find left" },
  --     { "sh",                      desc = "Surround: highlight" },
  --     { "sn",                      desc = "Surround: update n_lines" },
  --   },
  --   opts = {
  --     -- Number of lines to search for surrounding
  --     n_lines = 20,

  --     -- Highlight duration (ms) for 'sh'
  --     highlight_duration = 500,

  --     -- Keymaps (all use 's' prefix — consistent with vim-surround muscle memory)
  --     mappings = {
  --       add            = "sa",
  --       delete         = "sd",
  --       find           = "sf",
  --       find_left      = "sF",
  --       highlight      = "sh",
  --       replace        = "sr",
  --       update_n_lines = "sn",
  --     },

  --     -- Respect common surrounding pairs
  --     custom_surroundings = {
  --       -- Function call: saf → func(cursor)
  --       -- (in addition to built-in (, [, {, ", ', `)
  --     },
  --   },
  -- },

  -- ===========================================================================
  -- 6. oil.nvim — Directory-as-buffer file manager
  -- ===========================================================================
  -- SSH-friendly: renders as plain text buffer, no tree widget.
  -- '-'         → open parent directory (oil default)
  -- <leader>fe  → open current file's directory
  -- <leader>fE  → open cwd
  {
    "stevearc/oil.nvim",
    -- Load on '-' key or explicit open commands
    keys = {
      { "-",          "<cmd>Oil<CR>",                         desc = "File manager: open parent dir" },
      { "<leader>fe", "<cmd>Oil<CR>",                         desc = "File manager: open" },
      { "<leader>fE", function() require("oil").open(vim.loop.cwd()) end,
                                                              desc = "File manager: open cwd" },
    },
    cmd  = { "Oil" },
    -- oil.nvim is NOT a dependency for any other plugin; load on demand
    lazy = true,
     -- dependencies = { "echasnovski/mini.icons" },

    opts = {
      -- Default file manager (replaces netrw for directory arguments)
      default_file_explorer = true,

      -- oil buffer display
      columns = {
        "icon",
--        "permissions",
        "size",
        -- "mtime",   -- enable if you want modification time
      },

      -- Buffer-local keymaps inside oil
      keymaps = {
        ["g?"]  = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = "actions.select_vsplit",
        ["<C-h>"] = "actions.select_split",
        ["<C-t>"] = "actions.select_tab",
        ["<C-p>"] = "actions.preview",
        ["<C-r>"] = "actions.refresh",
        ["-"]     = "actions.parent",
        ["_"]     = "actions.open_cwd",
        ["`"]     = "actions.cd",
        ["~"]     = { "actions.cd", opts = { scope = "tab" } },
        ["gs"]    = "actions.change_sort",
        ["gx"]    = "actions.open_external",
        ["g."]    = "actions.toggle_hidden",
        ["g\\"]   = "actions.toggle_trash",
      },
      use_default_keymaps = false,  -- only use the ones above

      -- Show hidden files by default? Opt-in with g.
      view_options = {
        show_hidden = false,
        -- Natural sort: "file10" comes after "file9"
        natural_order = true,
        sort = {
          { "type", "asc" },
          { "name", "asc" },
        },
      },

      -- Float window (used when oil is opened in a float)
      float = {
        padding     = 2,
        max_width   = 0,
        max_height  = 0,
        border      = "rounded",
        win_options = { winblend = 0 },  -- no transparency (SSH)
      },

      -- Preview window
      preview = {
        max_width   = 0.9,
        min_width   = { 40, 0.4 },
        width       = nil,
        max_height  = 0.9,
        min_height  = { 5, 0.1 },
        height      = nil,
        border      = "rounded",
        win_options = { winblend = 0 },
      },

      -- Confirmation for delete/move/rename
      confirmation = {
        max_width  = { 40, 0.4 },
        min_width  = { 20, 0.2 },
        width      = nil,
        max_height = 0.9,
        min_height = { 5, 0.1 },
        height     = nil,
        border     = "rounded",
        win_options = { winblend = 0 },
      },

      -- Skip confirmation for these actions
      skip_confirm_for_simple_edits = false,

      -- Automatically update oil when file system changes
      watch_for_changes = not util.is_ssh, -- disable fs watch over SSH

      -- Restore cursor to last position in oil buffer
      restore_win_options = true,
    },
  },
}
