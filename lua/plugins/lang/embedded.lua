-- =============================================================================
-- lua/plugins/lang/embedded.lua — ESP32 & Raspberry Pi
-- =============================================================================
-- Existing infrastructure reused from earlier steps:
--   clangd LSP      → lsp/clangd.lua      (step 4, NVIM_CLANGD_PATH)
--   codelldb DAP    → plugins/dap.lua      (step 10, NVIM_CODELLDB_PATH)
--   toggleterm      → plugins/lang/python.lua (step 8)
--
-- This step adds:
--   · C/C++ embedded filetype options
--   · Kconfig / sdkconfig filetype detection
--   · compile_commands.json helper (clangd needs this for ESP-IDF projects)
--   · ESP-IDF terminal commands  (idf.py build/flash/monitor/menuconfig)
--   · Rust embedded commands     (cargo-espflash, probe-rs flash)
--   · Serial monitor             (picocom / screen)
--   · probe-rs DAP adapter       (extends step 10 dap.lua)
--
-- Buffer-local keymaps (C/C++ files — <leader>l language group):
--   <leader>lb   build         (idf.py build  or  cargo build)
--   <leader>lf   flash         (idf.py flash  or  cargo espflash)
--   <leader>lm   monitor       (idf.py monitor)
--   <leader>lM   menuconfig    (idf.py menuconfig)
--   <leader>lc   clean         (idf.py fullclean  or  cargo clean)
--   <leader>ls   serial        (picocom on NVIM_SERIAL_PORT)
--   <leader>lk   create .clangd file pointing to build/ directory
--   <leader>lp   flash via probe-rs (if NVIM_PROBE_RS_PATH set)
--
-- Environment variables:
--   NVIM_ESP_IDF_PATH    — ESP-IDF root (or IDF_PATH)
--   NVIM_OPENOCD_PATH    — OpenOCD binary (optional; probe-rs preferred)
--   NVIM_PROBE_RS_PATH   — probe-rs binary (cargo install probe-rs-tools)
--   NVIM_PROBE_RS_CHIP   — chip target  e.g. "esp32s3" "esp32" "rp2040"
--   NVIM_SERIAL_PORT     — serial device e.g. "/dev/ttyUSB0" "/dev/ttyACM0"
--   NVIM_CLANGD_PATH     — clangd binary (step 4)
--   NVIM_CODELLDB_PATH   — codelldb binary (step 10)
-- =============================================================================

local util = require("util")

-- =============================================================================
-- Resolve ESP-IDF path (NVIM_ESP_IDF_PATH takes priority, then IDF_PATH)
-- =============================================================================
local function idf_path()
  return util.env("NVIM_ESP_IDF_PATH") or vim.env.IDF_PATH
end

local function idf_py()
  local idf = idf_path()
  if idf then return idf .. "/tools/idf.py" end
  -- fall back to idf.py on PATH
  if vim.fn.executable("idf.py") == 1 then return "idf.py" end
  return nil
end

-- =============================================================================
-- Module-level setup (runs at spec-import time — only autocmds/keymaps)
-- =============================================================================

do
  -- -------------------------------------------------------------------------
  -- Kconfig and sdkconfig filetype detection (ESP-IDF)
  -- -------------------------------------------------------------------------
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group   = vim.api.nvim_create_augroup("config_embedded_ft", { clear = true }),
    pattern = { "Kconfig", "Kconfig.*", "sdkconfig", "sdkconfig.*" },
    callback = function()
      vim.bo.filetype = "kconfig"
    end,
    desc = "ESP-IDF: Kconfig/sdkconfig filetype",
  })

  -- -------------------------------------------------------------------------
  -- C/C++ embedded filetype options + buffer-local keymaps
  -- -------------------------------------------------------------------------
  vim.api.nvim_create_autocmd("FileType", {
    group   = vim.api.nvim_create_augroup("config_embedded_c", { clear = true }),
    pattern = { "c", "cpp" },
    callback = function(ev)
      local buf = ev.buf

      -- Embedded C typically uses 4-space indent, no system-style 80 cols
      vim.opt_local.tabstop     = 4
      vim.opt_local.shiftwidth  = 4
      vim.opt_local.expandtab   = true
      vim.opt_local.colorcolumn = "100,120"
      vim.opt_local.smartindent = false  -- let clangd / treesitter handle it

      -- -----------------------------------------------------------------------
      -- Helper: run a command in a toggleterm float, keep open after exit
      -- -----------------------------------------------------------------------
      local function run(cmd, title)
        return function()
          local ok, Terminal = pcall(
            function() return require("toggleterm.terminal").Terminal end
          )
          if ok then
            Terminal:new({
              cmd           = cmd,
              direction     = "float",
              close_on_exit = false,
              float_opts    = {
                border = "rounded",
                title  = " " .. (title or cmd) .. " ",
              },
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

      -- -----------------------------------------------------------------------
      -- Detect project type: ESP-IDF (CMake), Rust embedded, or plain CMake
      -- -----------------------------------------------------------------------
      local cwd = vim.fn.getcwd()
      local is_esp_idf = vim.fn.filereadable(cwd .. "/sdkconfig") == 1
                      or vim.fn.filereadable(cwd .. "/CMakeLists.txt") == 1
                         and idf_path() ~= nil
      local is_rust    = vim.fn.filereadable(cwd .. "/Cargo.toml") == 1

      if is_rust then
        -- Rust embedded (esp-rs / rp2040 / etc.)
        map("<leader>lb", run("cargo build",        "cargo build"),    "Embedded: cargo build")
        map("<leader>lc", run("cargo clean",        "cargo clean"),    "Embedded: cargo clean")

        -- cargo-espflash (ESP32 Rust)
        local espflash = vim.fn.executable("cargo-espflash") == 1
          and "cargo espflash flash --monitor"
          or  "cargo run"
        map("<leader>lf", run(espflash, "espflash"), "Embedded: flash (espflash)")

        -- probe-rs flash
        if util.env("NVIM_PROBE_RS_PATH") then
          local chip = util.env("NVIM_PROBE_RS_CHIP") or "esp32s3"
          map("<leader>lp", run(
            vim.env.NVIM_PROBE_RS_PATH
              .. " download --chip " .. chip .. " target/debug/*.elf",
            "probe-rs flash"
          ), "Embedded: flash via probe-rs")
        end

      elseif is_esp_idf then
        -- ESP-IDF (C/C++ via idf.py)
        local idf = idf_py()
        if idf then
          map("<leader>lb", run(idf .. " build",      "idf.py build"),      "ESP-IDF: build")
          map("<leader>lf", run(idf .. " flash",      "idf.py flash"),      "ESP-IDF: flash")
          map("<leader>lm", run(idf .. " monitor",    "idf.py monitor"),    "ESP-IDF: monitor")
          map("<leader>lM", run(idf .. " menuconfig", "idf.py menuconfig"), "ESP-IDF: menuconfig")
          map("<leader>lc", run(idf .. " fullclean",  "idf.py fullclean"),  "ESP-IDF: clean")
          -- Build + flash + monitor in one command
          map("<leader>lB", run(
            idf .. " build flash monitor",
            "idf.py build+flash+monitor"
          ), "ESP-IDF: build → flash → monitor")
        end

        -- probe-rs for ESP32 (alternative to idf.py flash)
        if util.env("NVIM_PROBE_RS_PATH") then
          local chip = util.env("NVIM_PROBE_RS_CHIP") or "esp32s3"
          map("<leader>lp", run(
            vim.env.NVIM_PROBE_RS_PATH
              .. " download --chip " .. chip .. " build/*.elf",
            "probe-rs flash"
          ), "Embedded: flash via probe-rs")
        end

      else
        -- Generic CMake project (RPi bare-metal, etc.)
        map("<leader>lb", run(
          "cmake --build build --parallel $(nproc)",
          "cmake build"
        ), "CMake: build")
        map("<leader>lc", run("cmake --build build --target clean", "cmake clean"),
          "CMake: clean")
        map("<leader>lC", run(
          "rm -rf build && cmake -B build -G Ninja",
          "cmake configure"
        ), "CMake: reconfigure")
      end

      -- -----------------------------------------------------------------------
      -- Serial monitor (all project types)
      -- -----------------------------------------------------------------------
      map("<leader>ls", function()
        local port = util.env("NVIM_SERIAL_PORT") or "/dev/ttyUSB0"
        local baud = "115200"
        -- Use picocom if available, fall back to screen
        local cmd
        if vim.fn.executable("picocom") == 1 then
          cmd = "picocom -b " .. baud .. " " .. port
        elseif vim.fn.executable("screen") == 1 then
          cmd = "screen " .. port .. " " .. baud
        else
          vim.notify("Install picocom or screen for serial monitor", vim.log.levels.WARN)
          return
        end
        run(cmd, "serial monitor " .. port)()
      end, "Embedded: serial monitor")

      -- -----------------------------------------------------------------------
      -- compile_commands.json → .clangd helper
      -- -----------------------------------------------------------------------
      -- ESP-IDF puts compile_commands.json in build/.
      -- clangd searches for it upward from the source file, and finds it only
      -- in the project root or parents. This keymap creates a .clangd file
      -- that tells clangd where to look.
      map("<leader>lk", function()
        local root = cwd
        local clangd_file = root .. "/.clangd"

        -- Check if compile_commands.json exists in build/
        local build_db = root .. "/build/compile_commands.json"
        local has_build_db = vim.uv.fs_stat(build_db) ~= nil

        if not has_build_db then
          vim.notify(
            "build/compile_commands.json not found.\n"
              .. "Run 'idf.py build' first, or 'cmake -B build' for CMake projects.",
            vim.log.levels.WARN
          )
          return
        end

        local content = "CompileFlags:\n  CompilationDatabase: build\n"
        local fd = io.open(clangd_file, "w")
        if fd then
          fd:write(content)
          fd:close()
          vim.notify(".clangd created → clangd will use build/compile_commands.json\nRestart LSP: :LspRestart", vim.log.levels.INFO)
        else
          vim.notify("Failed to write .clangd: " .. clangd_file, vim.log.levels.ERROR)
        end
      end, "Embedded: create .clangd for build/compile_commands.json")
    end,
    desc = "Embedded: C/C++ filetype options and project keymaps",
  })

  -- -------------------------------------------------------------------------
  -- probe-rs DAP adapter (extends step 10 dap.lua)
  -- Registered here via vim.schedule so dap is guaranteed to be set up first.
  -- -------------------------------------------------------------------------
  if util.env("NVIM_PROBE_RS_PATH") then
    vim.schedule(function()
      local ok, dap = pcall(require, "dap")
      if not ok then return end

      local chip = util.env("NVIM_PROBE_RS_CHIP") or "esp32s3"

      dap.adapters["probe-rs"] = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.env.NVIM_PROBE_RS_PATH,
          args    = { "dap-server", "--port", "${port}" },
        },
      }

      dap.configurations.c = dap.configurations.c or {}
      dap.configurations.cpp = dap.configurations.cpp or {}

      local probe_rs_config = {
        {
          type    = "probe-rs",
          request = "attach",
          name    = "probe-rs: attach to " .. chip,
          chip    = chip,
          cwd     = "${workspaceFolder}",
          speed   = 4000,   -- JTAG/SWD speed in kHz
          rttEnabled = true,
          coreIndex  = 0,
        },
        {
          type    = "probe-rs",
          request = "launch",
          name    = "probe-rs: flash and debug " .. chip,
          chip    = chip,
          cwd     = "${workspaceFolder}",
          flashingConfig = {
            flashingEnabled        = true,
            resetAfterFlashing     = true,
            haltAfterReset         = true,
            fullChipErase          = false,
            restoreUnwrittenBytes  = false,
          },
          program = function()
            return vim.fn.input(
              "ELF binary: ",
              vim.fn.getcwd() .. "/build/",
              "file"
            )
          end,
        },
      }

      for _, cfg in ipairs(probe_rs_config) do
        table.insert(dap.configurations.c,   cfg)
        table.insert(dap.configurations.cpp, cfg)
        -- Also add to rust configs if probe-rs is preferred over codelldb
        dap.configurations.rust = dap.configurations.rust or {}
        table.insert(dap.configurations.rust, cfg)
      end
    end)
  end
end

-- =============================================================================
-- Plugin specs
-- =============================================================================
-- No new plugins needed for embedded development:
--   · clangd LSP is already running (lsp/clangd.lua, step 4)
--   · codelldb DAP is already configured (plugins/dap.lua, step 10)
--   · probe-rs DAP adapter registered above (module-level, no plugin)
--   · toggleterm is already loaded (plugins/lang/python.lua, step 8)
--
-- Install system tools (Gentoo):
--   emerge dev-util/cmake dev-util/ninja dev-embedded/openocd
--   emerge dev-embedded/esptool                  # or pip install esptool
--   cargo install probe-rs-tools                 # probe-rs
--   cargo install cargo-espflash                 # Rust ESP32 flashing
--   emerge dev-libs/picocom                      # serial monitor
-- =============================================================================

return {}
