return {
  {
    'mfussenegger/nvim-dap',
    ft = 'cs',
    dependencies = {
      'mason-org/mason.nvim',
      'jay-babu/mason-nvim-dap.nvim',
      'rcarriga/nvim-dap-ui',
      'nvim-neotest/nvim-nio',
    },
    keys = {
      {
        '<F5>',
        function()
          require('dap').continue()
        end,
        desc = 'Debug: Start/Continue',
      },
      {
        '<F1>',
        function()
          require('dap').step_into()
        end,
        desc = 'Debug: Step Into',
      },
      {
        '<F2>',
        function()
          require('dap').step_over()
        end,
        desc = 'Debug: Step Over',
      },
      {
        '<F3>',
        function()
          require('dap').step_out()
        end,
        desc = 'Debug: Step Out',
      },
      {
        '<leader>b',
        function()
          require('dap').toggle_breakpoint()
        end,
        desc = 'Debug: Toggle Breakpoint',
      },
      {
        '<leader>B',
        function()
          require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Debug: Set Breakpoint',
      },
      {
        '<F7>',
        function()
          require('dap').disconnect { terminateDebuggee = false }
        end,
        desc = 'Debug: Detach (keep process running)',
      },
      {
        '<F8>',
        function()
          require('dapui').toggle()
        end,
        desc = 'Debug: Toggle UI',
      },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      require('mason-nvim-dap').setup {
        automatic_installation = true,
        ensure_installed = { 'netcoredbg' },
        handlers = {},
      }

      local path_separator = package.config:sub(1, 1)
      local netcoredbg_path = table.concat({
        vim.fn.stdpath 'data',
        'mason',
        'packages',
        'netcoredbg',
        'netcoredbg',
        'netcoredbg',
      }, path_separator)

      if vim.fn.has 'win32' == 1 then
        netcoredbg_path = netcoredbg_path .. '.exe'
      end

      dap.adapters.coreclr = {
        type = 'executable',
        command = netcoredbg_path,
        args = { '--interpreter=vscode' },
      }

      -- Finds .NET processes whose command line contains `pattern` (e.g. the isolated
      -- Azure Functions worker, which runs as plain `dotnet.exe Scdip.Functions.dll`).
      local function pick_process_by_cmdline(pattern)
        return function()
          local ps = string.format(
            [[Get-CimInstance Win32_Process -Filter "Name='dotnet.exe' or Name like '%%%s%%'" | Where-Object { $_.CommandLine -like '*%s*' } | ForEach-Object { "$($_.ProcessId)`t$($_.CommandLine)" }]],
            pattern,
            pattern
          )
          local lines = vim.fn.systemlist { 'powershell', '-NoProfile', '-Command', ps }
          local procs = {}
          for _, line in ipairs(lines) do
            local pid, cmd = line:match '^(%d+)\t(.*)$'
            if pid then
              table.insert(procs, { pid = tonumber(pid), cmd = cmd })
            end
          end
          if #procs == 0 then
            vim.notify('No running process found for ' .. pattern, vim.log.levels.WARN)
            return require('dap').ABORT
          end
          if #procs == 1 then
            return procs[1].pid
          end
          return coroutine.create(function(co)
            vim.ui.select(procs, {
              prompt = 'Select ' .. pattern .. ' process',
              format_item = function(p)
                return p.pid .. '  ' .. p.cmd
              end,
            }, function(choice)
              coroutine.resume(co, choice and choice.pid or require('dap').ABORT)
            end)
          end)
        end
      end

      dap.configurations.cs = {
        {
          type = 'coreclr',
          name = 'Attach to Scdip.Functions',
          request = 'attach',
          processId = pick_process_by_cmdline 'Scdip.Functions',
        },
        {
          type = 'coreclr',
          name = 'Launch .NET assembly',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. path_separator .. 'bin' .. path_separator .. 'Debug' .. path_separator, 'file')
          end,
        },
        {
          type = 'coreclr',
          name = 'Attach to .NET process',
          request = 'attach',
          processId = require('dap.utils').pick_process,
        },
      }

      dapui.setup()

      -- Breakpoint icons: red dot instead of the letter "B"
      vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
      vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
      local breakpoint_icons = {
        Breakpoint = '●',
        BreakpointCondition = '◆',
        BreakpointRejected = '○',
        LogPoint = '◆',
        Stopped = '▶',
      }
      for type, icon in pairs(breakpoint_icons) do
        local name = 'Dap' .. type
        local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
        vim.fn.sign_define(name, { text = icon, texthl = hl, numhl = '' })
      end
      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close
    end,
  },
}
