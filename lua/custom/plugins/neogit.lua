return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'sindrets/diffview.nvim',
    'nvim-telescope/telescope.nvim',
  },
  cmd = { 'Neogit' },
  keys = {
    { '<leader>gg', '<cmd>Neogit<cr>', desc = '[G]it status (neo[g]it)' },
    { '<leader>gc', '<cmd>Neogit commit<cr>', desc = '[G]it [C]ommit' },
    { '<leader>gp', '<cmd>Neogit pull<cr>', desc = '[G]it [P]ull' },
    { '<leader>gP', '<cmd>Neogit push<cr>', desc = '[G]it [P]ush' },
  },
  opts = {
    integrations = {
      diffview = true,
      telescope = true,
    },
  },
}
