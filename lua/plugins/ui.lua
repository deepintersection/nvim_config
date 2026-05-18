-- =============================================================================
-- lua/plugins/ui.lua — UI plugins
-- =============================================================================
-- Plugins:
--   catppuccin       — colorscheme (compiled, SSH-fast after first run)
--   lualine          — statusline (uses 0.12 vim.lsp.status / diagnostic.count)
--   which-key v3     — leader group labels
--   nvim-web-devicons — icon provider (Nerd Font icons for filetypes/files)
--   snacks.nvim      — bigfile handler, notifier, optional indent guides
--
-- Environment variables consumed:
--   NVIM_THEME         — colorscheme name (default: catppuccin-mocha)
--                        options: catppuccin-latte | frappe | macchiato | mocha
--   NVIM_INDENT_GUIDES — "1" to enable indent guides (default: off)
-- =============================================================================

local util = require("util")

return {

  -- ===========================================================================
  -- 1. Colorscheme — catppuccin
  -- ===========================================================================
  {
    "catppuccin/nvim",
    name     = "catppuccin",
    lazy     = false,    -- must load at startup
    priority = 1000,     -- before everything else
    build    = ":CatppuccinCompile",  -- compile to bytecode on install/update
    opts = {
      -- Flavour from env var, default mocha
      -- Supports both "catppuccin-mocha" and "mocha"
      flavour = (function()
        local theme = util.env("NVIM_THEME") or "catppuccin-mocha"
        return theme:gsub("^catppuccin%-", "")
      end)(),

      background = { light = "latte", dark = "mocha" },

      -- Compiled cache: loads in ~0.2ms on subsequent startups
      compile_path = vim.fn.stdpath("cache") .. "/catppuccin",
      compile      = true,

      transparent_background = false,

      -- No dim for unfocused windows — causes redraw flicker over SSH
      dim_inactive = {
        enabled    = false,
        shade      = "dark",
        percentage = 0.15,
      },

      styles = {
        comments     = { "italic" },
        conditionals = {},
        loops        = {},
        functions    = {},
        keywords     = {},
        strings      = {},
        variables    = {},
        numbers      = {},
        booleans     = {},
        properties   = {},
        types        = {},
      },

      integrations = {
        treesitter       = true,
        native_lsp       = {
          enabled      = true,
          virtual_text = {
            errors   = { "italic" },
            hints    = { "italic" },
            warnings = { "italic" },
            information = { "italic" },
          },
          underlines   = {
            errors   = { "underline" },
            hints    = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
          inlay_hints  = { background = true },
        },
        blink_cmp        = true,    -- completion (step 6)
        gitsigns         = true,
        which_key        = true,
        snacks           = true,
        fzf              = true,
        dap              = true,
        dap_ui           = true,
        -- Disable integrations for plugins we're not using
        cmp              = false,
        telescope        = false,
        indent_blankline = { enabled = false },
      },
    },

    config = function(_, opts)
      require("catppuccin").setup(opts)

      local theme = util.env("NVIM_THEME") or "catppuccin-mocha"
      local ok = pcall(vim.cmd.colorscheme, theme)
      if not ok then
        vim.notify(
          ("[ui] colorscheme '%s' not found — using habamax fallback"):format(theme),
          vim.log.levels.WARN
        )
        vim.cmd.colorscheme("habamax")
      end
    end,
  },

  -- ===========================================================================
  -- 2. Statusline — lualine
  -- ===========================================================================
  {
    "nvim-lualine/lualine.nvim",
    event        = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },

    opts = function()
      -- -----------------------------------------------------------------
      -- Custom components using Neovim 0.12 public APIs
      -- -----------------------------------------------------------------

      --- LSP progress string — vim.lsp.status() is new in 0.12.
      local function lsp_status()
        local s = vim.lsp.status()
        if s == "" then return "" end
        -- Truncate long spinner messages (common over slow SSH connections)
        if #s > 40 then s = s:sub(1, 37) .. "…" end
        return " " .. s
      end

      --- Diagnostic counts — vim.diagnostic.count() is the 0.12 API.
      --- (vim.lsp.diagnostic.* was removed in 0.12.)
      local function diagnostics_component()
        -- count(bufnr) returns table keyed by severity integer
        local counts = vim.diagnostic.count(0)
        local E = counts[vim.diagnostic.severity.ERROR]   or 0
        local W = counts[vim.diagnostic.severity.WARN]    or 0
        local I = counts[vim.diagnostic.severity.INFO]    or 0
        local H = counts[vim.diagnostic.severity.HINT]    or 0
        local parts = {}
        if E > 0 then parts[#parts + 1] = " "  .. E end
        if W > 0 then parts[#parts + 1] = " "  .. W end
        if I > 0 then parts[#parts + 1] = " "  .. I end
        if H > 0 then parts[#parts + 1] = "󰌵 " .. H end
        return table.concat(parts, " ")
      end

      --- Attached LSP client names (compact).
      local function lsp_clients()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return "" end
        local names = vim.tbl_map(function(c) return c.name end, clients)
        local s = table.concat(names, ", ")
        if #s > 30 then return (" [%d LSP]"):format(#clients) end
        return " " .. s
      end

      --- Active profile badge (python / rust / esp32 / rpi)
      local function profile_badge()
        local p = vim.env.NVIM_PROFILE
        if not p or p == "" or p == "default" then return "" end
        return "[" .. p .. "]"
      end

      --- SSH indicator
      local function ssh_badge()
        if util.is_ssh then return "󰌘 SSH" end
        return ""
      end

      -- -----------------------------------------------------------------
      -- Lualine config
      -- -----------------------------------------------------------------
      return {
        options = {
          theme                = "catppuccin-mocha",
          component_separators = { left = "", right = "" },
          section_separators   = { left = "", right = "" },
          globalstatus         = true,   -- requires laststatus=3
          -- Slower refresh over SSH to reduce terminal traffic
          refresh = {
            statusline = util.is_ssh and 2000 or 1000,
            tabline    = 2000,
            winbar     = 2000,
          },
          disabled_filetypes = {
            statusline = { "lazy", "mason" },
            winbar     = { "lazy", "neo-tree", "toggleterm" },
          },
        },

        sections = {
          lualine_a = { "mode" },

          lualine_b = {
            {
              "branch",
              icon = "",
            },
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
              -- Source from gitsigns when available
              source = function()
                local gs = vim.b.gitsigns_status_dict
                if gs then
                  return { added = gs.added, modified = gs.changed, removed = gs.removed }
                end
              end,
            },
          },

          lualine_c = {
            {
              "filename",
              path    = 1,  -- relative path
              symbols = {
                modified = "●",
                readonly = "",
                unnamed  = "[No Name]",
                newfile  = "[New]",
              },
            },
          },

          lualine_x = {
            diagnostics_component,
            lsp_status,
            lsp_clients,
          },

          lualine_y = {
            profile_badge,
            ssh_badge,
            "filetype",
            "encoding",
          },

          lualine_z = {
            { "location" },
            { "progress" },
          },
        },

        inactive_sections = {
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
        },

        -- Tabline: open buffers left, tab pages right
        tabline = {
          lualine_a = {
            {
              "buffers",
              show_filename_only      = true,
              hide_filename_extension = false,
              show_modified_status    = true,
              mode                    = 2,   -- name + index
              symbols = {
                modified       = " ●",
                alternate_file = "#",
                directory      = "",
              },
            },
          },
          lualine_z = { "tabs" },
        },

        extensions = { "lazy", "man", "quickfix" },
      }
    end,
  },

  -- ===========================================================================
  -- 3. Which-key v3 — key group labels
  -- ===========================================================================
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset  = "modern",
      delay   = 500,
      timeout = true,

      plugins = {
        marks     = true,
        registers = true,
        spelling  = { enabled = true, suggestions = 20 },
        presets   = {
          operators    = false,  -- too noisy
          motions      = false,
          text_objects = false,
          windows      = true,
          nav          = true,
          z            = true,
          g            = true,
        },
      },

      win = {
        border  = "rounded",
        padding = { 1, 2 },
        wo      = { winblend = 0 },  -- no transparency (unreliable over SSH)
      },

      layout = {
        width   = { min = 20 },
        spacing = 3,
      },

      icons = {
        breadcrumb = "»",
        separator  = "→",
        group      = "+",
        mappings   = true,   -- use nvim-web-devicons
        colors     = true,
      },

      show_help = true,
      show_keys = true,
    },

    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)

      -- Register leader groups (v3 API uses wk.add(), not wk.register())
      -- Matching groups defined in lua/core/keymaps.lua
      wk.add({
        -- Leader groups
        { "<leader>b",  group = "buffer"           },
        { "<leader>c",  group = "code"             },
        { "<leader>d",  group = "diagnostics"      },
        { "<leader>f",  group = "find / files"     },
        { "<leader>g",  group = "git"              },
        { "<leader>l",  group = "language / lint"  },
        { "<leader>q",  group = "quit"             },
        { "<leader>s",  group = "search / replace" },
        { "<leader>t",  group = "tabs / terminal"  },
        { "<leader>u",  group = "ui toggles"       },
        { "<leader>w",  group = "window / write"   },
        { "<leader>x",  group = "lists / trouble"  },

        -- nvim-surround operator groups (ys/ds/cs are operator-pending)
        { "ys",  group = "surround add"    },
        { "ds",  group = "surround delete" },
        { "cs",  group = "surround change" },

        -- 0.12 built-in LSP mappings (document them, do NOT override)
        -- gra, gri, grn, grr, grt, grx are default in 0.12
        { "gr",  group = "LSP (0.12 built-ins)"       },
        { "g",   group = "goto"                        },

        -- Visual mode leader
        { "<leader>", group = "leader", mode = "v" },

        -- Window management
        { "<C-w>", group = "window" },
      })
    end,
  },

  -- ===========================================================================
  -- 4. nvim-web-devicons — icon provider
  -- ===========================================================================
  -- Standard Nerd Font icon provider used by lualine, oil.nvim, fzf-lua, etc.
  -- Requires a Nerd Font installed and set in your terminal.
  -- On Gentoo: emerge media-fonts/nerd-fonts  (or install a single font manually)
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,   -- loaded on demand by plugins that need icons
    opts = {
      -- Override specific file icons
      override = {
        [".env"] = {
          icon  = "",
          color = "#EBD06F",
          name  = "Env",
        },
        [".env.example"] = {
          icon  = "",
          color = "#7a7a7a",
          name  = "EnvExample",
        },
      },
      -- Override by filetype
      override_by_filename = {},
      override_by_extension = {
        ["toml"] = { icon = "", color = "#E37B27", name = "Toml" },
        ["rs"]   = { icon = "", color = "#DEA584", name = "Rust" },
      },
      -- Use default icons for everything else
      default = true,
      strict  = true,
    },
  },

  -- ===========================================================================
  -- 5. snacks.nvim — bigfile, notifier, indent guides
  -- ===========================================================================
  {
    "folke/snacks.nvim",
    priority = 900,  -- after colorscheme (1000), before most plugins
    lazy     = false,

    ---@type snacks.Config
    opts = {

      -- -----------------------------------------------------------------------
      -- bigfile: disable expensive features for large files.
      -- Critical for SSH: prevents treesitter/LSP freezes on large logs.
      -- -----------------------------------------------------------------------
      bigfile = {
        enabled    = true,
        notify     = true,
        size       = 1.5 * 1024 * 1024,  -- 1.5 MB threshold
        line_count = 10000,               -- or 10 000 lines
        setup = function(ctx)
          -- ctx.buf and ctx.ft are available here
          vim.cmd("syntax clear")
          vim.opt_local.filetype   = "bigfile"  -- prevents further ft detection
          vim.opt_local.swapfile   = false
          vim.opt_local.foldmethod = "manual"
          vim.opt_local.undolevels = -1
          vim.opt_local.undoreload = 0
          vim.opt_local.list       = false
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ctx.buf) then
              vim.bo[ctx.buf].syntax = ""
            end
          end)
        end,
      },

      -- -----------------------------------------------------------------------
      -- notifier: replaces vim.notify with a tidy floating notification stack.
      -- -----------------------------------------------------------------------
      notifier = {
        enabled  = true,
        timeout  = 3000,
        width    = { min = 10, max = 0.4 },
        height   = { min = 1,  max = 0.6 },
        margin   = { top = 0, right = 1, bottom = 0 },
        padding  = true,
        sort     = { "level", "added" },
        level    = vim.log.levels.TRACE,
        icons    = {
          error = " ",
          warn  = " ",
          info  = " ",
          debug = " ",
          trace = " ",
        },
        style    = "compact",   -- compact | minimal | fancy
        top_down = false,       -- stack from bottom-right
      },

      -- -----------------------------------------------------------------------
      -- indent: guides — disabled by default, opt-in with NVIM_INDENT_GUIDES=1
      -- Skipped over SSH to avoid extra render traffic.
      -- -----------------------------------------------------------------------
      indent = {
        enabled = util.env_bool("NVIM_INDENT_GUIDES", false),
        indent  = {
          char         = "│",
          only_scope   = false,
          only_current = false,
          hl           = "SnacksIndent",
        },
        scope   = {
          enabled      = true,
          char         = "│",
          underline    = false,
          only_current = true,
          hl           = "SnacksIndentScope",
        },
        -- No animation (SSH)
        animate = { enabled = false },
      },

      -- Explicitly disable all other snacks modules
      dashboard    = { enabled = false },
      explorer     = { enabled = false },
      picker       = { enabled = false },  -- using fzf-lua
      scroll       = { enabled = false },  -- too heavy for SSH
      animate      = { enabled = false },
      words        = { enabled = false },
      lazygit      = { enabled = false },  -- using fugitive/gitsigns
      terminal     = { enabled = false },  -- using toggleterm
      zen          = { enabled = false },
      statuscolumn = { enabled = false },  -- managed via options.lua
      image        = { enabled = false },
    },

    config = function(_, opts)
      local snacks = require("snacks")
      snacks.setup(opts)

      -- Replace vim.notify globally after snacks initialises
      -- vim.notify = snacks.notify

      -- Global reference for keymaps below
      _G.Snacks = snacks
    end,

    -- Keymaps for UI toggles (<leader>u group)
    keys = {
      -- Indent guides toggle
      {
        "<leader>ui",
        function() if _G.Snacks then _G.Snacks.indent.toggle() end end,
        desc = "Toggle indent guides",
      },
      -- Notification history
      {
        "<leader>un",
        function() if _G.Snacks then _G.Snacks.notifier.show_history() end end,
        desc = "Notification history",
      },
      -- Dismiss all notifications
      {
        "<leader>uD",
        function() if _G.Snacks then _G.Snacks.notifier.hide() end end,
        desc = "Dismiss all notifications",
      },
      -- Toggle relative numbers
      {
        "<leader>ur",
        function() vim.opt.relativenumber = not vim.opt.relativenumber:get() end,
        desc = "Toggle relative numbers",
      },
      -- Toggle line wrap
      {
        "<leader>uw",
        function() vim.opt.wrap = not vim.opt.wrap:get() end,
        desc = "Toggle line wrap",
      },
      -- Toggle spell
      {
        "<leader>us",
        function() vim.opt.spell = not vim.opt.spell:get() end,
        desc = "Toggle spell check",
      },
      -- Toggle diagnostics (0.12 API: vim.diagnostic.enable / is_enabled)
      {
        "<leader>ud",
        function()
          local enabled = vim.diagnostic.is_enabled({ bufnr = 0 })
          vim.diagnostic.enable(not enabled, { bufnr = 0 })
          vim.notify(
            "Diagnostics " .. (not enabled and "enabled" or "disabled"),
            vim.log.levels.INFO
          )
        end,
        desc = "Toggle diagnostics",
      },
      -- Toggle inlay hints (0.10+ built-in, works in 0.12)
      {
        "<leader>uh",
        function()
          local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
          vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
        end,
        desc = "Toggle inlay hints",
      },
    },
  },
}
