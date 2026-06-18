return {
  {
    'seblyng/roslyn.nvim',
    commit = 'f2ec6ee6384c3b611ddc817b9e78b20cd0334bbb',
    ft = 'cs',
    dependencies = {
      'mason-org/mason.nvim',
    },
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      filewatching = 'roslyn',
      broad_search = true,
      lock_target = false,
      choose_target = function(targets)
        return vim.iter(targets):find(function(item)
          return item:match 'EntryPoint%.slnf$'
        end)
      end,
    },
    config = function(_, opts)
      require('roslyn').setup(opts)

      local mason = vim.fn.expand '$MASON'
      if mason == '$MASON' then
        mason = vim.fs.joinpath(vim.fn.stdpath 'data', 'mason')
      end
      local roslyn_exe = vim.fs.joinpath(mason, 'bin', 'roslyn-language-server.cmd')

      vim.lsp.config('roslyn', {
        cmd = {
          roslyn_exe,
          '--logLevel=Information',
          '--extensionLogDirectory=' .. vim.fs.dirname(vim.lsp.log.get_filename()),
          '--stdio',
        },
        settings = {
          ['csharp|inlay_hints'] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
          },
          ['csharp|code_lens'] = {
            dotnet_enable_references_code_lens = true,
            dotnet_enable_tests_code_lens = true,
          },
          ['csharp|background_analysis'] = {
            dotnet_analyzer_diagnostics_scope = 'fullSolution',
            dotnet_compiler_diagnostics_scope = 'fullSolution',
          },
          ['csharp|completion'] = {
            dotnet_show_completion_items_from_unimported_namespaces = true,
          },
        },
      })
    end,
  },
}

