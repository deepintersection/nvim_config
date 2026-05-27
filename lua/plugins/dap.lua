-- =============================================================================
-- lua/plugins/dap.lua — Debug Adapter Protocol
-- =============================================================================
-- Plugins:
--   nvim-dap              — DAP client core
--   nvim-dap-ui           — Variables, watches, stack, console UI
--   nvim-dap-virtual-text — Inline variable values as virtual text
--
-- Adapters configured here:
--   debugpy  — Python (uses NVIM_PYTHON_PATH; debugpy must be in that venv)
--   codelldb — Rust / C / C++ (uses NVIM_CODELLDB_PATH)
--   nlua/osv — Lua / Neovim config (jbyuki/one-small-step-for-vimkind)
--             No external binary — pure Lua, runs inside Neovim itself.
--
-- Adapters referenced elsewhere:
--   codelldb — neotest-rust (lang/rust.lua) uses dap_adapter='codelldb'
--   debugpy  — neotest-python can launch tests under debugpy
--
-- Keymaps:
--   F-keys (universal, fast access):
--     <F5>   continue / start session
--     <F9>   toggle breakpoint
--     <F10>  step over
--     <F11>  step into
--     <F12>  step out
--
--   <leader>D group (debug — uppercase D; lowercase d = diagnostics):
--     <leader>Db   toggle breakpoint
--     <leader>DB   conditional breakpoint
--     <leader>Dl   log point (message breakpoint)
--     <leader>Dc   continue
--     <leader>Di   step into
--     <leader>Do   step out
--     <leader>Ds   step over
--     <leader>Dr   REPL open
--     <leader>Dv   variable hover (dap.ui.widgets)
--     <leader>Dw   add watch expression
--     <leader>Du   toggle DAP UI
--     <leader>Dt   terminate session
--     <leader>Dp   pause
--     <leader>Dk   run to cursor (k because ]c is taken)
--     <leader>Dn   launch osv DAP server  (Lua/Neovim debugging)
--     <leader>DR   run_this()             (debug current Lua file in-place)
--
-- Lua / Neovim config debugging workflow:
--   Method A — in-place (single Neovim instance):
--     1. Open any .lua file (your config, a plugin, a script)
--     2. Set breakpoints with <F9>
--     3. <leader>DR → osv runs the file; execution stops at breakpoints
--        Variables visible in DAP UI, step with F10/F11/F12
--
--   Method B — cross-instance (two Neovim instances):
--     1. In Neovim A (the one you want to debug): <leader>Dn
--        → prints port (default 8086), starts listening
--     2. In Neovim B: open the same .lua file, set breakpoints, <F5>
--        → attaches to A; trigger the code in A to hit breakpoints
--
--   Note: breakpoints are path-sensitive — open the exact same file path
--   in both instances. Config files (init.lua, plugins/*.lua) work fine.
--
-- Environment variables:
--   NVIM_PYTHON_PATH    — Python interpreter with debugpy installed
--   NVIM_CODELLDB_PATH  — codelldb binary path
--                         Download: https://github.com/vadimcn/codelldb/releases
--                         Gentoo: no portage package — download binary directly
-- =============================================================================

local util = require("util")

return {

  -- ===========================================================================
  -- 1. nvim-dap — core DAP client
  -- ===========================================================================
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "jbyuki/one-small-step-for-vimkind",  -- Lua/Neovim DAP adapter (no binary needed)
    },
    -- Load on debug keymaps only
    keys = {
      { "<F5>",        desc = "Debug: continue / start" },
      { "<F9>",        desc = "Debug: toggle breakpoint" },
      { "<F10>",       desc = "Debug: step over" },
      { "<F11>",       desc = "Debug: step into" },
      { "<F12>",       desc = "Debug: step out" },
      { "<leader>Db",  desc = "Debug: toggle breakpoint" },
      { "<leader>DB",  desc = "Debug: conditional breakpoint" },
      { "<leader>Dl",  desc = "Debug: log point" },
      { "<leader>Dc",  desc = "Debug: continue" },
      { "<leader>Di",  desc = "Debug: step into" },
      { "<leader>Do",  desc = "Debug: step out" },
      { "<leader>Ds",  desc = "Debug: step over" },
      { "<leader>Dr",  desc = "Debug: REPL" },
      { "<leader>Dv",  desc = "Debug: variable hover" },
      { "<leader>Dw",  desc = "Debug: add watch" },
      { "<leader>Du",  desc = "Debug: toggle UI" },
      { "<leader>Dt",  desc = "Debug: terminate" },
      { "<leader>Dp",  desc = "Debug: pause" },
      { "<leader>Dk",  desc = "Debug: run to cursor" },
      { "<leader>Dn",  desc = "Debug: launch Lua DAP server (osv)" },
      { "<leader>DR",  desc = "Debug: run this Lua file (osv)" },
      { "<F4>",        desc = "Debug: restart session" },
      { "<leader>Dj",  desc = "Debug: jump into DAP float" },
      { "<leader>Df",  desc = "Debug: open REPL float (focused)" },
    },

    config = function()
      local dap = require("dap")

      -- -----------------------------------------------------------------------
      -- Signs (DAP-specific — use vim.fn.sign_define, NOT vim.diagnostic API)
      -- -----------------------------------------------------------------------
      vim.fn.sign_define("DapBreakpoint", {
        text   = "●",
        texthl = "DapBreakpoint",
        numhl  = "DapBreakpoint",
      })
      vim.fn.sign_define("DapBreakpointCondition", {
        text   = "◉",
        texthl = "DapBreakpointCondition",
        numhl  = "DapBreakpointCondition",
      })
      vim.fn.sign_define("DapBreakpointRejected", {
        text   = "○",
        texthl = "DapBreakpointRejected",
        numhl  = "",
      })
      vim.fn.sign_define("DapLogPoint", {
        text   = "◆",
        texthl = "DapLogPoint",
        numhl  = "",
      })
      vim.fn.sign_define("DapStopped", {
        text    = "→",
        texthl  = "DapStopped",
        linehl  = "DapStoppedLine",
        numhl   = "DapStopped",
      })

      -- -----------------------------------------------------------------------
      -- Python adapter — debugpy
      -- -----------------------------------------------------------------------
      -- debugpy must be installed in the Python environment:
      --   pip install debugpy
      -- The adapter uses NVIM_PYTHON_PATH (the venv interpreter).
      -- -----------------------------------------------------------------------
      if util.env("NVIM_PYTHON_PATH") then
        local python = vim.env.NVIM_PYTHON_PATH

        dap.adapters.python = function(cb, config)
          if config.request == "attach" then
            -- Remote attach: connect to a running debugpy server
            local port = (config.connect or config).port
            local host = (config.connect or config).host or "127.0.0.1"
            cb({
              type = "server",
              port = assert(port, "debugpy attach: 'port' is required"),
              host = host,
              options = { source_filetype = "python" },
            })
          else
            -- Local launch: start debugpy as a subprocess
            cb({
              type    = "executable",
              command = python,
              args    = { "-m", "debugpy.adapter" },
              options = { source_filetype = "python" },
            })
          end
        end

        dap.configurations.python = {
          {
            type    = "python",
            request = "launch",
            name    = "Launch file",
            program = "${file}",
            pythonPath = python,
          },
          {
            type    = "python",
            request = "launch",
            name    = "Launch with arguments",
            program = "${file}",
            args    = function()
              local args = vim.fn.input("Args: ")
              return vim.split(args, " ", { plain = true })
            end,
            pythonPath = python,
          },
          {
            type    = "python",
            request = "launch",
            name    = "Django: runserver",
            program = "${workspaceFolder}/manage.py",
            args    = { "runserver", "--noreload" },
            django  = true,
            pythonPath = python,
          },
          {
            type    = "python",
            request = "launch",
            name    = "Pytest: current file",
            module  = "pytest",
            args    = { "${file}", "-v", "-s" },
            pythonPath = python,
            console = "integratedTerminal",
          },
          {
            type      = "python",
            request   = "attach",
            name      = "Attach to running process",
            processId = require("dap.utils").pick_process,
            pythonPath = python,
          },
          {
            type    = "python",
            request = "attach",
            name    = "Attach to debugpy server (host:port)",
            connect = {
              host = function() return vim.fn.input("Host [127.0.0.1]: ") end,
              port = function()
                return tonumber(vim.fn.input("Port [5678]: ") or "5678") or 5678
              end,
            },
            pythonPath = python,
          },
        }
      end

      -- -----------------------------------------------------------------------
      -- codelldb adapter — Rust / C / C++
      -- -----------------------------------------------------------------------
      -- Download from: https://github.com/vadimcn/codelldb/releases
      -- Extract the archive and set NVIM_CODELLDB_PATH to the codelldb binary.
      -- Gentoo: no portage package — download binary directly.
      -- -----------------------------------------------------------------------
      local codelldb_path = util.env("NVIM_CODELLDB_PATH")
      if codelldb_path then
        dap.adapters.codelldb = {
          type       = "server",
          port       = "${port}",
          executable = {
            command = codelldb_path,
            args    = { "--port", "${port}" },
            -- Detach process so codelldb survives nvim restarts
            detached = vim.fn.has("win32") == 0,
          },
        }

        -- Helper: find the debug binary for the current Cargo project
        local function cargo_binary()
          -- Try to read package name from Cargo.toml
          local cargo_toml = vim.fn.findfile("Cargo.toml", vim.fn.getcwd() .. ";")
          local name = nil
          if cargo_toml ~= "" then
            for line in io.lines(cargo_toml) do
              local m = line:match('^name%s*=%s*"([^"]+)"')
              if m then name = m; break end
            end
          end
          local default = vim.fn.getcwd() .. "/target/debug/" .. (name or "")
          return vim.fn.input("Binary path: ", default, "file")
        end

        local codelldb_configs = {
          {
            type    = "codelldb",
            request = "launch",
            name    = "Launch debug binary",
            program = cargo_binary,
            cwd     = "${workspaceFolder}",
            stopOnEntry = false,
            args    = {},
          },
          {
            type    = "codelldb",
            request = "launch",
            name    = "cargo build → launch",
            program = function()
              -- Build first, then launch the output binary
              vim.notify("Running cargo build…", vim.log.levels.INFO)
              local out = vim.fn.system("cargo build 2>&1")
              if vim.v.shell_error ~= 0 then
                vim.notify("cargo build failed:\n" .. out, vim.log.levels.ERROR)
                return dap.ABORT
              end
              return cargo_binary()
            end,
            cwd     = "${workspaceFolder}",
            stopOnEntry = false,
            args    = {},
          },
          {
            type    = "codelldb",
            request = "launch",
            name    = "Launch with arguments",
            program = cargo_binary,
            cwd     = "${workspaceFolder}",
            stopOnEntry = false,
            args    = function()
              local args = vim.fn.input("Args: ")
              return vim.split(args, " ", { plain = true })
            end,
          },
          {
            type      = "codelldb",
            request   = "attach",
            name      = "Attach to process",
            pid       = require("dap.utils").pick_process,
            cwd       = "${workspaceFolder}",
          },
        }

        dap.configurations.rust = codelldb_configs
        dap.configurations.c    = codelldb_configs
        dap.configurations.cpp  = codelldb_configs
      end

      -- -----------------------------------------------------------------------
      -- Lua / Neovim config adapter — osv (one-small-step-for-vimkind)
      -- -----------------------------------------------------------------------
      -- No external binary. osv is pure Lua that hooks into Neovim's debug API.
      -- Works for: init.lua, any plugin file, any .lua script.
      -- -----------------------------------------------------------------------
      dap.adapters.nlua = function(callback, config)
        callback({
          type = "server",
          host = config.host or "127.0.0.1",
          port = config.port or 8086,
        })
      end

      dap.configurations.lua = {
        {
          type    = "nlua",
          request = "attach",
          name    = "Attach to running Neovim instance (osv)",
          -- Host and port where osv is listening (launched with <leader>Dn)
          host    = "127.0.0.1",
          port    = 8086,
        },
        {
          type    = "nlua",
          request = "attach",
          name    = "Attach to Neovim (prompt for port)",
          host    = "127.0.0.1",
          port    = function()
            local port = tonumber(vim.fn.input("OSV port [8086]: "))
            return port ~= 0 and port or 8086
          end,
        },
      }

      -- -----------------------------------------------------------------------
      -- Keymaps
      -- -----------------------------------------------------------------------
      local map = function(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
      end

      -- F-keys: fast access to the most common debug actions
      map("<F5>",  dap.continue,       "Debug: continue / start")
      map("<F9>",  dap.toggle_breakpoint, "Debug: toggle breakpoint")
      map("<F10>", dap.step_over,      "Debug: step over")
      map("<F11>", dap.step_into,      "Debug: step into")
      map("<F12>", dap.step_out,       "Debug: step out")

      -- <leader>D group
      map("<leader>Dc", dap.continue,               "Debug: continue")
      map("<leader>Di", dap.step_into,              "Debug: step into")
      map("<leader>Do", dap.step_out,               "Debug: step out")
      map("<leader>Ds", dap.step_over,              "Debug: step over")
      map("<leader>Dp", dap.pause,                  "Debug: pause")
      map("<leader>Dk", dap.run_to_cursor,          "Debug: run to cursor")
      map("<leader>Dt", dap.terminate,              "Debug: terminate")
      map("<leader>Dr", dap.repl.open,              "Debug: REPL")

      map("<leader>Db", dap.toggle_breakpoint,      "Debug: toggle breakpoint")
      map("<leader>DB", function()
        dap.set_breakpoint(vim.fn.input("Condition: "))
      end, "Debug: conditional breakpoint")
      map("<leader>Dl", function()
        dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
      end, "Debug: log point")

      -- Variable hover (uses dap.ui.widgets — available without dap-ui)
      map("<leader>Dv", function()
        require("dap.ui.widgets").hover()
      end, "Debug: variable hover")

      -- Preview scoped widgets
      map("<leader>Dw", function()
        local widgets = require("dap.ui.widgets")
        widgets.centered_float(widgets.scopes)
      end, "Debug: scopes float")

      -- Rerun last session
      map("<leader>DL", dap.run_last, "Debug: run last")

      -- Restart session
      map("<F4>", dap.restart, "Debug: restart session")

      -- -----------------------------------------------------------------------
      -- DAP float / window focus helpers
      -- -----------------------------------------------------------------------
      -- When dap-ui shows a floating "session active" overlay but the cursor
      -- is in the main buffer, use these to interact without entering the float:
      --
      --   <leader>Dt  terminate    (= "Terminate session" button)
      --   <leader>Dp  pause        (= "Pause thread" button)
      --   <F4>        restart      (= "Restart session" button)
      --   <F5>        continue     (= "Continue" button)
      --
      -- Or jump focus INTO the float with <leader>Dj, then q/<Esc> to leave.

      -- Jump cursor into the first visible DAP/dap-ui floating window.
      -- Works for the "session active" overlay, variable hover, widgets, etc.
      map("<leader>Dj", function()
        local target = nil
        local current = vim.api.nvim_get_current_win()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if win ~= current then
            local cfg = vim.api.nvim_win_get_config(win)
            if cfg.relative ~= "" then  -- it's a floating window
              target = win
              break
            end
          end
        end
        if target then
          vim.api.nvim_set_current_win(target)
          -- Make sure q and <Esc> close this float
          local buf = vim.api.nvim_win_get_buf(target)
          for _, key in ipairs({ "q", "<Esc>" }) do
            if vim.fn.maparg(key, "n", false, true).buffer ~= 1 then
              vim.keymap.set("n", key, "<cmd>close<CR>",
                { buffer = buf, silent = true, nowait = true, desc = "Close DAP float" })
            end
          end
        else
          vim.notify("No floating window visible", vim.log.levels.INFO)
        end
      end, "Debug: jump focus into DAP float")

      -- Open the dap-ui controls element as a focused float (alternative)
      map("<leader>Df", function()
        require("dapui").float_element("repl", {
          width    = 80,
          height   = 20,
          enter    = true,   -- immediately focus inside
          position = "center",
        })
      end, "Debug: open REPL float (focused)")

      -- -----------------------------------------------------------------------
      -- Lua / Neovim config debugging (osv)
      -- -----------------------------------------------------------------------
      -- Launch a DAP server in the current Neovim (Method B cross-instance)
      map("<leader>Dn", function()
        require("osv").launch({ port = 8086 })
      end, "Debug: launch Lua DAP server (osv, port 8086)")

      -- Run the current Lua file under the debugger (Method A in-place)
      -- Set breakpoints first, then call this. osv will stop at them.
      map("<leader>DR", function()
        require("osv").run_this()
      end, "Debug: run this Lua file (osv)")

      -- -----------------------------------------------------------------------
      -- Auto-open/close DAP UI on session events
      -- (dap-ui plugin wires these in its own config below)
      -- -----------------------------------------------------------------------
    end,
  },

  -- ===========================================================================
  -- 2. nvim-dap-ui — Debug UI panels
  -- ===========================================================================
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",  -- already a dep of neotest
    },
    keys = {
      { "<leader>Du", desc = "Debug: toggle UI" },
    },

    opts = {
      -- UI layout: two rows
      -- Top: scopes (variables) + watches + stacks
      -- Bottom: console (REPL output) + output (program stdout/stderr)
      layouts = {
        {
          elements = {
            { id = "scopes",      size = 0.4 },
            { id = "watches",     size = 0.25 },
            { id = "stacks",      size = 0.25 },
            { id = "breakpoints", size = 0.1 },
          },
          position = "left",
          size     = 40,
        },
        {
          elements = {
            { id = "repl",    size = 0.45 },
            { id = "console", size = 0.55 },
          },
          position = "bottom",
          size     = 12,
        },
      },

      controls = {
        enabled  = true,
        element  = "repl",
        icons    = {
          pause         = "",
          play          = "",
          step_into     = "",
          step_over     = "",
          step_out      = "",
          step_back     = "",
          run_last      = "",
          terminate     = "",
          disconnect    = "",
        },
      },

      floating = {
        max_height  = 0.9,
        max_width   = 0.9,
        border      = "rounded",
        mappings    = {
          close = { "q", "<Esc>" },  -- exit float with q or Esc
        },
      },

      icons = {
        collapsed = "",
        expanded  = "",
        current_frame = "",
      },

      render = {
        indent         = 2,
        max_type_length = nil,
        max_value_lines = 100,
      },

      -- Open automatically when DAP session starts
      expand_lines = true,
      force_buffers = true,
    },

    config = function(_, opts)
      local dap    = require("dap")
      local dapui  = require("dapui")

      dapui.setup(opts)

      -- Toggle UI keymap
      vim.keymap.set("n", "<leader>Du", dapui.toggle,
        { silent = true, desc = "Debug: toggle UI" })

      -- Auto-open on session start, auto-close on session end
      dap.listeners.before.attach["dapui_config"]   = function() dapui.open() end
      dap.listeners.before.launch["dapui_config"]   = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },

  -- ===========================================================================
  -- 3. nvim-dap-virtual-text — Inline variable values
  -- ===========================================================================
  -- Shows current variable values as virtual text to the right of each line.
  -- Disabled over SSH (extra render traffic) and for large files.
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-treesitter/nvim-treesitter-textobjects", -- for TS node queries
    },
    opts = {
      enabled                   = true,
      enabled_commands          = true,
      highlight_changed_variables = true,
      highlight_new_as_changed  = false,
      show_stop_reason          = true,

      -- Disable in insert mode (distracting while typing)
      commented                 = false,
      only_first_definition     = true,
      all_references            = false,

      -- Virtual text position
      virt_text_pos             = "eol",  -- end of line
      all_frames                = false,  -- only current frame

      -- Disable over SSH or for large files
      filter_references_pattern = nil,
      display_callback = function(variable, _, _, _, options)
        -- SSH: skip virtual text entirely
        if util.is_ssh then return nil end
        -- Large files: skip
        if vim.api.nvim_buf_line_count(0) > 5000 then return nil end
        -- Truncate long values
        local val = variable.value
        if #val > 50 then val = val:sub(1, 47) .. "…" end
        return options.virt_text_pos == "inline"
          and (" = " .. val)
          or (" = " .. val)
      end,

      virt_lines              = false,
      virt_text_win_col       = nil,
    },
  },
}
