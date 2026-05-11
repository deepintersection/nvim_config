-- =============================================================================
--  plugins/ui/statusline.lua — lualine.nvim
--  Cyberpunk layout:
--    [MODE] [GIT] [FILENAME·FLAGS]  ···  [DIAGNOSTICS]  ···  [FT] [ENC] [POS]
-- =============================================================================

-- Custom component: show active venv name (reads NVIM_VENV env var)
local function venv_component()
  local venv = vim.env.NVIM_VENV
  if not venv or venv == "" then return "" end
  -- Show just the last directory component
  local name = vim.fn.fnamemodify(venv, ":t")
  return "󰌠 " .. name
end

-- Custom component: LSP server names for current buffer
local function lsp_component()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then return "" end
  local names = vim.tbl_map(function(c) return c.name end, clients)
  return "󰒍 " .. table.concat(names, " ")
end

-- Custom component: show macro recording indicator
local function macro_component()
  local reg = vim.fn.reg_recording()
  if reg == "" then return "" end
  return "● REC @" .. reg
end

return {
  {
    "nvim-lualine/lualine.nvim",
    lazy  = false,   -- statusline must always be visible
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme                = "cyberdream",
        component_separators = { left = "│", right = "│" },
        section_separators   = { left = "", right = "" },
        globalstatus         = true,   -- single statusline for all windows
        refresh              = { statusline = 200 },
      },

      sections = {
        -- ----- LEFT --------------------------------------------------------
        lualine_a = {
          {
            "mode",
            fmt = function(str)
              -- Short uppercase mode with a neon prefix glyph
              local icons = {
                NORMAL   = "  ",
                INSERT   = "  ",
                VISUAL   = "  ",
                ["V-LINE"]  = " 󰈊 ",
                ["V-BLOCK"] = "  ",
                COMMAND  = "  ",
                TERMINAL = "  ",
                REPLACE  = "  ",
              }
              return (icons[str] or "  ") .. str
            end,
          },
        },

        lualine_b = {
          {
            "branch",
            icon = "",
            color = { fg = "#00ffff" },
          },
          {
            "diff",
            symbols = { added = " ", modified = " ", removed = " " },
            diff_color = {
              added    = { fg = "#00ff87" },
              modified = { fg = "#ffaf00" },
              removed  = { fg = "#ff005f" },
            },
          },
        },

        lualine_c = {
          {
            "filename",
            path     = 1,         -- relative path
            newfile_status = true,
            symbols = {
              modified = " ●",
              readonly = "  ",
              unnamed  = " [No Name]",
              newfile  = "  ",
            },
          },
          {
            macro_component,
            color = { fg = "#ff007c", gui = "bold" },
          },
        },

        -- ----- MIDDLE (empty = centred spacer) ------------------------------
        lualine_x = {
          {
            "diagnostics",
            sources  = { "nvim_lsp" },
            sections = { "error", "warn", "info", "hint" },
            symbols  = {
              error = " ",
              warn  = " ",
              info  = " ",
              hint  = "󰌵 ",
            },
            diagnostics_color = {
              error = { fg = "#ff005f" },
              warn  = { fg = "#ffaf00" },
              info  = { fg = "#00d7ff" },
              hint  = { fg = "#87ff00" },
            },
          },
          {
            lsp_component,
            color = { fg = "#bd00ff" },
          },
          {
            venv_component,
            color = { fg = "#00ffaf" },
          },
        },

        -- ----- RIGHT -------------------------------------------------------
        lualine_y = {
          {
            "filetype",
            icon_only = false,
          },
          {
            "encoding",
            fmt = string.upper,
          },
          {
            "fileformat",
            symbols = { unix = "LF", dos = "CRLF", mac = "CR" },
          },
        },

        lualine_z = {
          {
            "progress",
            fmt = function(str) return " " .. str end,
          },
          {
            "location",
            fmt = function(str) return "󰍒 " .. str end,
          },
        },
      },

      -- Inactive windows show minimal info
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },

      -- Winbar (top of each window): full file path breadcrumb
      -- Will be enhanced in the LSP step with navic symbols
      winbar = {
        lualine_c = {
          {
            "filename",
            path = 1,
            color = { fg = "#808080", gui = "italic" },
          },
        },
      },
      inactive_winbar = {
        lualine_c = {
          {
            "filename",
            path = 1,
            color = { fg = "#404040", gui = "italic" },
          },
        },
      },
    },
  },
}
