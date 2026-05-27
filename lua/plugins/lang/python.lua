-- =============================================================================
-- lua/plugins/lang/python.lua — Python & Django
-- =============================================================================
-- Covers:
--   · Python filetype options & Django template detection
--   · toggleterm.nvim  — shared float terminal + Python/IPython REPL
--   · neotest + neotest-python  — pytest runner
--
-- DAP (debugpy) is configured in plugins/dap.lua (step 10).
-- LSP (pyright + ruff) is configured in lsp/pyright.lua + lsp/ruff.lua.
-- Formatters (ruff_format, black) in plugins/editor.lua (conform).
--
-- Keymaps added here:
--   <leader>t group (tabs / terminal — extends core/keymaps.lua):
--     <C-\>        toggle float terminal  (any mode)
--     <leader>tt   toggle float terminal
--     <leader>tp   Python REPL  (uses NVIM_PYTHON_PATH or active venv)
--     <leader>ti   IPython REPL (uses venv ipython if available)
--     <leader>tm   Django manage.py shell
--
--   <leader>T group (test — new group):
--     <leader>Tr   run nearest test
--     <leader>Tf   run file
--     <leader>Ts   toggle summary panel
--     <leader>To   toggle output panel
--     <leader>TX   stop running tests
--     <leader>Tl   run last test
--
--   <leader>l group (language):
--     <leader>lr   run current file  (:python %)
--     <leader>ls   send line/selection to REPL
--
-- Environment variables:
--   NVIM_PYTHON_PATH   — interpreter used for REPL and neotest-python
--   NVIM_DEBUGPY_PATH  — debugpy path (used in dap.lua step 10)
-- =============================================================================

local util = require("util")

-- =============================================================================
-- Module-level: Python filetype options & Django template detection
-- Runs at spec-import time — safe (just creates autocmds).
-- =============================================================================

do
  local py_group = vim.api.nvim_create_augroup("config_python_ft", { clear = true })

  -- Python filetype options
  vim.api.nvim_create_autocmd("FileType", {
    group   = py_group,
    pattern = "python",
    callback = function()
      -- Black uses 88, PEP8 uses 79. We show both rulers.
      vim.opt_local.textwidth   = 88
      vim.opt_local.colorcolumn = "88,120"
      -- Already set globally: tabstop=4, shiftwidth=4, expandtab=true
      -- Disable smartindent for Python (conflicts with indentexpr)
      vim.opt_local.smartindent = false
    end,
    desc = "Python: filetype options",
  })

  -- Django HTML template detection.
  -- Files in templates/ directories or named *.html inside Django projects
  -- are set to htmldjango for syntax + LSP (if yamlls configured for YAML).
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group   = py_group,
    pattern = "*/templates/*.html",
    callback = function()
      vim.bo.filetype = "htmldjango"
    end,
    desc = "Django: set htmldjango for templates/ HTML files",
  })

  -- Django management command keymaps (Python-specific, not buffer-local)
  -- These are global and only useful in Python projects.
  vim.keymap.set("n", "<leader>tm", function()
    local python = util.env("NVIM_PYTHON_PATH") or "python3"
    -- Find manage.py from cwd upwards
    local manage = vim.fn.findfile("manage.py", vim.fn.getcwd() .. ";")
    if manage == "" then
      vim.notify("manage.py not found in project", vim.log.levels.WARN)
      return
    end
    -- Open a toggleterm terminal running manage.py shell
    -- (toggleterm is loaded lazily; use a pcall)
    local ok, tt = pcall(require, "toggleterm.terminal")
    if not ok then
      vim.notify("toggleterm not loaded yet — open a terminal first", vim.log.levels.INFO)
      return
    end
    tt.Terminal:new({
      cmd        = python .. " " .. manage .. " shell",
      direction  = "float",
      float_opts = { border = "rounded" },
      on_open    = function(term)
        vim.cmd("startinsert!")
        vim.api.nvim_buf_set_keymap(
          term.bufnr, "t", "q", "<cmd>close<CR>", { noremap = true }
        )
      end,
    }):toggle()
  end, { desc = "Django: manage.py shell" })
end

-- =============================================================================
-- Plugin specs
-- =============================================================================

return {

  -- ===========================================================================
  -- 1. toggleterm.nvim — floating terminal + language REPLs
  -- ===========================================================================
  -- Shared across all languages; placed here because Python REPL is the
  -- primary use case. Other lang files (rust, embedded) reuse the same plugin.
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    -- Load on explicit keymaps or Ctrl-\
    keys = {
      { [[<C-\>]],     mode = { "n", "t", "i" }, desc = "Terminal: toggle float" },
      { "<leader>tt",  desc = "Terminal: toggle float" },
      { "<leader>tp",  desc = "Terminal: Python REPL" },
      { "<leader>ti",  desc = "Terminal: IPython REPL" },
    },
    cmd = { "ToggleTerm", "TermExec" },

    opts = {
      -- Default terminal size (used for horizontal/vertical splits)
      size = function(term)
        if term.direction == "horizontal" then return 15
        elseif term.direction == "vertical" then
          return math.floor(vim.o.columns * 0.4)
        end
      end,

      -- Float terminal (our default)
      open_mapping    = [[<C-\>]],
      hide_numbers    = true,
      shade_terminals = false,
      shading_factor  = 0,
      start_in_insert = true,
      insert_mappings = true,   -- <C-\> works in insert mode too
      terminal_mappings = true,
      persist_size    = true,
      persist_mode    = true,
      direction       = "float",
      close_on_exit   = true,
      shell           = vim.o.shell,
      auto_scroll     = true,

      float_opts = {
        border        = "rounded",
        width         = math.floor(vim.o.columns * 0.85),
        height        = math.floor(vim.o.lines * 0.85),
        winblend      = 0,    -- no transparency (SSH)
        title_pos     = "center",
      },

      -- Highlight the terminal border
      highlights = {
        Normal     = { link = "Normal" },
        NormalFloat = { link = "NormalFloat" },
        FloatBorder = { link = "FloatBorder" },
      },
    },

    config = function(_, opts)
      require("toggleterm").setup(opts)

      local Terminal = require("toggleterm.terminal").Terminal

      -- -----------------------------------------------------------------------
      -- Python REPL terminal
      -- -----------------------------------------------------------------------
      local function python_cmd()
        -- Use explicit NVIM_PYTHON_PATH, fall back to active venv, then python3
        local path = util.env("NVIM_PYTHON_PATH")
        if path then return path end
        if vim.env.VIRTUAL_ENV then
          return vim.env.VIRTUAL_ENV .. "/bin/python3"
        end
        return "python3"
      end

      local python_term = Terminal:new({
        cmd        = python_cmd(),
        direction  = "float",
        float_opts = { border = "rounded", title = " Python " },
        on_open    = function(_) vim.cmd("startinsert!") end,
      })

      -- IPython REPL (falls back to python if ipython not available)
      local function ipython_cmd()
        local venv = vim.env.VIRTUAL_ENV
        if venv then
          local ipython = venv .. "/bin/ipython"
          if vim.uv.fs_stat(ipython) then return ipython end
        end
        -- Check system ipython
        if vim.fn.executable("ipython") == 1 then return "ipython" end
        vim.notify("ipython not found — using python", vim.log.levels.INFO)
        return python_cmd()
      end

      local ipython_term = Terminal:new({
        cmd        = ipython_cmd(),
        direction  = "float",
        float_opts = { border = "rounded", title = " IPython " },
        on_open    = function(_) vim.cmd("startinsert!") end,
      })

      -- Generic float terminal (main <leader>tt)
      local float_term = Terminal:new({ direction = "float" })

      -- Keymaps
      vim.keymap.set("n", "<leader>tt", function() float_term:toggle() end,
        { desc = "Terminal: toggle float" })
      vim.keymap.set("n", "<leader>tp", function() python_term:toggle() end,
        { desc = "Terminal: Python REPL" })
      vim.keymap.set("n", "<leader>ti", function() ipython_term:toggle() end,
        { desc = "Terminal: IPython REPL" })

      -- -----------------------------------------------------------------------
      -- Send code to Python REPL
      -- -----------------------------------------------------------------------
      -- <leader>ls — send current line or visual selection to Python terminal
      vim.keymap.set("n", "<leader>ls", function()
        local line = vim.api.nvim_get_current_line()
        python_term:send(line, true)
        if not python_term:is_open() then python_term:open() end
      end, { desc = "Python: send line to REPL" })

      vim.keymap.set("v", "<leader>ls", function()
        -- Get visual selection
        local start_line = vim.fn.line("'<")
        local end_line   = vim.fn.line("'>")
        local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
        -- Dedent: find minimum indentation
        local min_indent = math.huge
        for _, l in ipairs(lines) do
          if l:match("%S") then
            local indent = l:match("^(%s*)"):len()
            min_indent = math.min(min_indent, indent)
          end
        end
        if min_indent == math.huge then min_indent = 0 end
        local dedented = vim.tbl_map(function(l)
          return l:sub(min_indent + 1)
        end, lines)
        -- Wrap in a block and send
        python_term:send(table.concat(dedented, "\n"), true)
        if not python_term:is_open() then python_term:open() end
      end, { desc = "Python: send selection to REPL" })

      -- <leader>lr — run current file
      vim.keymap.set("n", "<leader>lr", function()
        local file = vim.fn.expand("%:p")
        if vim.bo.filetype ~= "python" then
          vim.notify("Not a Python file", vim.log.levels.WARN)
          return
        end
        local cmd = python_cmd() .. " " .. vim.fn.shellescape(file)
        float_term:send(cmd, true)
        if not float_term:is_open() then float_term:open() end
      end, { desc = "Python: run file" })
    end,
  },

  -- ===========================================================================
  -- 2. neotest + neotest-python — pytest runner
  -- ===========================================================================
  -- Uses opts={} for static config so other lang files (rust.lua, etc.) can
  -- extend opts.adapters via lazy.nvim's merge pattern without re-calling setup.
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-neotest/neotest-python",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>Tr", desc = "Test: run nearest" },
      { "<leader>Tf", desc = "Test: run file" },
      { "<leader>Ts", desc = "Test: summary" },
      { "<leader>To", desc = "Test: output" },
      { "<leader>TX", desc = "Test: stop" },
      { "<leader>Tl", desc = "Test: run last" },
    },

    -- Static UI config — adapters are added below in config() so they can
    -- read runtime env vars. Other lang files extend adapters via opts function.
    opts = {
      adapters = {},   -- populated in config(); extended by rust.lua etc.

      status = {
        virtual_text = true,
        signs        = true,
      },
      output = {
        enabled     = true,
        open_on_run = false,
      },
      output_panel = {
        enabled = true,
        open    = "botright split | resize 15",
      },
      summary = {
        enabled       = true,
        animated      = false,
        follow        = true,
        expand_errors = true,
        open          = "botright vsplit | vertical resize 50",
      },
      icons = {
        child_indent       = "  ",
        child_prefix       = "  ",
        collapsed          = "",
        expanded           = "",
        failed             = " ",
        final_child_indent = "  ",
        final_child_prefix = "  ",
        non_collapsible    = "  ",
        passed             = " ",
        running            = " ",
        running_animated   = { "|", "/", "-", "\\" },
        skipped            = " ",
        unknown            = " ",
        watching           = " ",
      },
      diagnostic = {
        enabled  = true,
        severity = vim.diagnostic.severity.ERROR,
      },
      floating = {
        border     = "rounded",
        max_height = 0.8,
        max_width  = 0.8,
        options    = {},
      },
      quickfix = {
        enabled = false,
        open    = false,
      },
    },

    config = function(_, opts)
      local neotest = require("neotest")

      -- Add Python adapter (reads env vars at load time, not at spec time)
      local python_path = util.env("NVIM_PYTHON_PATH")
        or (vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV .. "/bin/python3")
        or "python3"

      table.insert(opts.adapters, require("neotest-python")({
        python = python_path,
        runner = "pytest",
        pytest_discovery_args = { "--tb=short", "-q" },
        args = { "--tb=short", "--no-header", "-rN" },
        is_test_file = function(file_path)
          return file_path:match("test_.*%.py$") ~= nil
            or file_path:match(".*_test%.py$") ~= nil
            or file_path:match("tests/.*%.py$") ~= nil
        end,
      }))

      neotest.setup(opts)

      -- Keymaps (<leader>T group — works for all languages)
      local map = function(lhs, fn, desc)
        vim.keymap.set("n", lhs, fn, { desc = desc, silent = true })
      end
      map("<leader>Tr", function() neotest.run.run() end,            "Test: run nearest")
      map("<leader>Tf", function() neotest.run.run(vim.fn.expand("%")) end, "Test: run file")
      map("<leader>Tl", function() neotest.run.run_last() end,       "Test: run last")
      map("<leader>TX", function() neotest.run.stop() end,           "Test: stop")
      map("<leader>Ts", function() neotest.summary.toggle() end,     "Test: summary panel")
      map("<leader>To", function() neotest.output.open({ enter = true }) end, "Test: output")
      map("<leader>TP", function() neotest.output_panel.toggle() end,"Test: output panel")
      map("]T", function() neotest.jump.next({ status = "failed" }) end, "Test: next failed")
      map("[T", function() neotest.jump.prev({ status = "failed" }) end, "Test: prev failed")
    end,
  },
}
