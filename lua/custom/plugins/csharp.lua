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

      dap.configurations.cs = {
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
      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close
    end,
  },
}
