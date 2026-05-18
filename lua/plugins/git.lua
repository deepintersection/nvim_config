-- =============================================================================
-- lua/plugins/git.lua — Git integration
-- =============================================================================
-- Plugins:
--   gitsigns.nvim   — hunk signs, staging, blame, ]c/[c navigation
--   vim-fugitive    — :Git command interface (commit, push, log, blame…)
--   diffview.nvim   — side-by-side diffs, file history, merge conflicts
--
-- Keymap layout (<leader>g group, registered in plugins/ui.lua step 2):
--   Hunks (gitsigns, buffer-local via on_attach):
--     ]c / [c          next / prev hunk  (smart: native in diff mode)
--     <leader>gs       stage hunk
--     <leader>gr       reset hunk
--     <leader>gS       stage buffer
--     <leader>gR       reset buffer
--     <leader>gu       undo stage hunk
--     <leader>gp       preview hunk (inline float)
--     <leader>gb       toggle line blame (virtual text)
--     <leader>gB       open blame split (full)
--     <leader>gd       diff this  (index)
--     <leader>gD       diff this~ (HEAD^)
--   Fugitive:
--     <leader>gg       :Git  (status window)
--     <leader>gG       :Git commit
--     <leader>gP       :Git push  (uppercase P — intentional)
--     <leader>gl       :Git log --oneline --graph
--     <leader>gf       :Git fetch --all
--   Diffview:
--     <leader>gv       DiffviewOpen  (working tree vs index)
--     <leader>gh       DiffviewFileHistory % (current file)
--     <leader>gH       DiffviewFileHistory   (whole branch)
--
-- Already mapped elsewhere (do NOT duplicate):
--   <leader>fgb/c/f   fzf-lua git branches / commits / files (editor.lua)
-- =============================================================================

return {

  -- ===========================================================================
  -- 1. gitsigns.nvim — inline git decorations
  -- ===========================================================================
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile", "BufWritePre" },

    opts = {
      -- -----------------------------------------------------------------------
      -- Sign column symbols
      -- -----------------------------------------------------------------------
      signs = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
        untracked    = { text = "▎" },
      },
      -- Staged hunks shown with a slightly different shade
      signs_staged = {
        add          = { text = "▎" },
        change       = { text = "▎" },
        delete       = { text = "" },
        topdelete    = { text = "" },
        changedelete = { text = "▎" },
      },
      signs_staged_enable = true,

      -- -----------------------------------------------------------------------
      -- Behaviour
      -- -----------------------------------------------------------------------
      signcolumn = true,
      numhl      = false,   -- don't highlight line numbers
      linehl     = false,   -- don't highlight whole lines
      word_diff  = false,   -- word-level diff inside hunks (toggle: <leader>gW)

      -- Watch the git directory for changes (index, HEAD, etc.)
      -- Disable over SSH to avoid extra file-watch overhead
      watch_gitdir = {
        follow_files = true,
      },

      -- Attach to all buffers including untracked files
      attach_to_untracked = false,

      -- Blame virtual text (toggle with <leader>gb)
      current_line_blame = false,
      current_line_blame_opts = {
        virt_text         = true,
        virt_text_pos     = "eol",
        delay             = 500,
        ignore_whitespace = false,
        virt_text_priority = 100,
      },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> · <summary>",

      -- Preview hunk float
      preview_config = {
        border   = "rounded",
        style    = "minimal",
        relative = "cursor",
        row      = 0,
        col      = 1,
      },

      -- -----------------------------------------------------------------------
      -- on_attach: buffer-local keymaps
      -- -----------------------------------------------------------------------
      on_attach = function(bufnr)
        local gs = require("gitsigns")

        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer  = bufnr,
            silent  = true,
            noremap = true,
            desc    = desc,
          })
        end

        -- Hunk navigation
        -- Smart ]c/[c: use native vim diff command in diff buffers,
        -- gitsigns hunk navigation otherwise.
        map("n", "]c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gs.nav_hunk("next")
          end
        end, "Git: next hunk")

        map("n", "[c", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gs.nav_hunk("prev")
          end
        end, "Git: prev hunk")

        -- Hunk operations (normal + visual)
        map({ "n", "v" }, "<leader>gs", function()
          -- In visual mode, stage only the selected lines
          if vim.fn.mode() == "v" then
            gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          else
            gs.stage_hunk()
          end
        end, "Git: stage hunk")

        map({ "n", "v" }, "<leader>gr", function()
          if vim.fn.mode() == "v" then
            gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          else
            gs.reset_hunk()
          end
        end, "Git: reset hunk")

        map("n", "<leader>gS", gs.stage_buffer,       "Git: stage buffer")
        map("n", "<leader>gR", gs.reset_buffer,       "Git: reset buffer")
        map("n", "<leader>gu", gs.undo_stage_hunk,    "Git: undo stage hunk")
        map("n", "<leader>gp", gs.preview_hunk_inline,"Git: preview hunk")

        -- Blame
        map("n", "<leader>gb", gs.toggle_current_line_blame, "Git: toggle blame line")
        map("n", "<leader>gB", function()
          gs.blame()
        end, "Git: blame split")

        -- Diff
        map("n", "<leader>gd", gs.diffthis,           "Git: diff this (index)")
        map("n", "<leader>gD", function()
          gs.diffthis("~")
        end, "Git: diff this~ (HEAD^)")

        -- Word diff toggle (useful for prose / long lines)
        map("n", "<leader>gW", gs.toggle_word_diff,   "Git: toggle word diff")

        -- Text objects: ih = inner hunk, ah = around hunk
        map({ "o", "x" }, "ih", gs.select_hunk,       "Git: select hunk")
        map({ "o", "x" }, "ah", gs.select_hunk,       "Git: select hunk (around)")
      end,
    },
  },

  -- ===========================================================================
  -- 2. vim-fugitive — Git command interface
  -- ===========================================================================
  {
    "tpope/vim-fugitive",
    cmd  = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gread", "Gwrite" },
    keys = {
      { "<leader>gg", "<cmd>Git<CR>",                        desc = "Git: status" },
      { "<leader>gG", "<cmd>Git commit<CR>",                 desc = "Git: commit" },
      { "<leader>gP", "<cmd>Git push<CR>",                   desc = "Git: push" },
      { "<leader>gl", "<cmd>Git log --oneline --graph<CR>",  desc = "Git: log (graph)" },
      { "<leader>gf", "<cmd>Git fetch --all<CR>",            desc = "Git: fetch all" },
      -- Quick file-level operations
      { "<leader>gw", "<cmd>Gwrite<CR>",                     desc = "Git: stage file (Gwrite)" },
      { "<leader>ge", "<cmd>Gedit<CR>",                      desc = "Git: edit (index version)" },
    },

    config = function()
      -- Fugitive buffer mappings — set inside fugitive windows
      vim.api.nvim_create_autocmd("FileType", {
        group   = vim.api.nvim_create_augroup("config_fugitive", { clear = true }),
        pattern = "fugitive",
        callback = function(ev)
          local buf = ev.buf
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, {
              buffer  = buf,
              silent  = true,
              noremap = true,
              desc    = desc,
            })
          end
          -- Quick actions from the fugitive status buffer
          map("q",  "<cmd>close<CR>",       "Fugitive: close")
          map("pp", "<cmd>Git push<CR>",    "Fugitive: push")
          map("pf", "<cmd>Git push --force-with-lease<CR>", "Fugitive: push (force-with-lease)")
          map("pl", "<cmd>Git pull<CR>",    "Fugitive: pull")
          map("rb", "<cmd>Git rebase<CR>",  "Fugitive: rebase")
          map("rf", "<cmd>Git rebase --autosquash<CR>", "Fugitive: rebase (autosquash)")
        end,
        desc = "Fugitive: buffer-local keymaps",
      })
    end,
  },

  -- ===========================================================================
  -- 3. diffview.nvim — rich diff and history viewer
  -- ===========================================================================
  -- Great for:
  --   · Reviewing staged/unstaged changes side-by-side
  --   · Browsing a file's full git history
  --   · Resolving merge conflicts (diff3 layout)
  {
    "sindrets/diffview.nvim",
    cmd  = {
      "DiffviewOpen", "DiffviewClose",
      "DiffviewToggleFiles", "DiffviewFocusFiles",
      "DiffviewFileHistory", "DiffviewRefresh",
    },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<CR>",            desc = "Git: diff view (index)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>",   desc = "Git: file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<CR>",     desc = "Git: branch history" },
      -- Close diffview from any buffer
      { "<leader>gx", "<cmd>DiffviewClose<CR>",           desc = "Git: close diff view" },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },

    opts = {
      diff_binaries    = false,
      enhanced_diff_hl = true,   -- better highlighting for changed words
      use_icons        = true,

      icons = {
        folder_closed = "",
        folder_open   = "",
      },
      signs = {
        fold_closed = "",
        fold_open   = "",
        done        = "✓",
      },

      view = {
        -- Working tree / staged diff
        default = {
          layout             = "diff2_horizontal",
          winbar_info        = false,
          disable_diagnostics = true,   -- no LSP diagnostics in diff buffers
        },
        -- Merge conflict resolution
        merge_tool = {
          layout             = "diff3_horizontal",
          disable_diagnostics = true,
          winbar_info        = true,
        },
        -- File history
        file_history = {
          layout             = "diff2_horizontal",
          winbar_info        = false,
        },
      },

      file_panel = {
        listing_style     = "tree",
        tree_options      = {
          flatten_dirs    = true,
          folder_statuses = "only_folded",
        },
        win_config        = {
          position = "left",
          width    = 35,
          win_opts = {},
        },
      },

      file_history_panel = {
        log_options = {
          git = {
            single_file = {
              diff_merges = "combined",
            },
            multi_file = {
              diff_merges = "first-parent",
            },
          },
        },
        win_config = {
          position = "bottom",
          height   = 16,
          win_opts = {},
        },
      },

      -- Keymaps inside diffview panels (supplement defaults)
      keymaps = {
        disable_defaults = false,
        view = {
          -- Close with q
          { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Diffview: close" } },
        },
        file_panel = {
          { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Diffview: close" } },
        },
        file_history_panel = {
          { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Diffview: close" } },
        },
      },

      hooks = {
        -- No hooks needed: blink.cmp is already disabled in diff buffers
        -- via its `enabled` function (add to completion.lua if needed:
        --   enabled = function()
        --     return vim.bo.buftype == "" and not vim.wo.diff
        --   end
        -- )
      },
    },
  },
}
