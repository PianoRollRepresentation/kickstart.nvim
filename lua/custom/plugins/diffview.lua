return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewFileHistory', 'DiffviewRefresh' },
  keys = {
    { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iff view' },
    { '<leader>gD', '<cmd>DiffviewClose<cr>', desc = '[G]it [D]iff close' },
    { '<leader>gh', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it file [H]istory (repo)' },
    { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it [F]ile history (current)' },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      merge_tool = {
        layout = 'diff3_mixed',
        disable_diagnostics = true,
      },
    },
    keymaps = {
      file_panel = {
        { 'n', 'm', '<Cmd>wincmd l<Bar>normal! ]c<CR>', { desc = 'Next change' } },
        { 'n', 'n', '<Cmd>wincmd l<Bar>normal! [c<CR>', { desc = 'Previous change' } },
      },
      view = {
        { 'n', 'm', ']c', { desc = 'Next change', remap = true } },
        { 'n', 'n', '[c', { desc = 'Previous change', remap = true } },
      },
    },
  },
}
