return {
  'sindrets/diffview.nvim',
  cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewToggleFiles', 'DiffviewFocusFiles', 'DiffviewFileHistory', 'DiffviewRefresh' },
  keys = {
    { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iff view' },
    { '<leader>gD', '<cmd>DiffviewClose<cr>', desc = '[G]it [D]iff close' },
    { '<leader>gh', '<cmd>DiffviewFileHistory<cr>', desc = '[G]it file [H]istory (repo)' },
    { '<leader>gf', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it [F]ile history (current)' },
  },
  init = function()
    -- Diffview's index buffers (diffview://.../.git/:0:/...) are normal buffers, so LSPs attach to them.
    -- Neovim can't find a project root for that fake path, falls back to '.', and on Windows then
    -- file-watches the whole drive (C:\), which crashes on protected files (EPERM in vim/_watch.lua).
    -- 'acwrite' keeps LSPs away; saving still works because Diffview stages via BufWriteCmd.
    vim.api.nvim_create_autocmd('BufFilePost', {
      group = vim.api.nvim_create_augroup('diffview-no-lsp', { clear = true }),
      pattern = 'diffview://*',
      callback = function(args)
        if vim.bo[args.buf].buftype == '' then
          vim.bo[args.buf].buftype = 'acwrite'
        end
      end,
    })
  end,
  opts = {
    enhanced_diff_hl = true,
    use_icons = vim.g.have_nerd_font,
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
  config = function(_, opts)
    require('diffview').setup(opts)

    -- Show added and deleted files as one whole file instead of a side-by-side diff against an
    -- empty side. Diffview has no option for this, so wrap the function that builds each file entry.
    local FileEntry = require('diffview.scene.file_entry').FileEntry
    local Diff1 = require('diffview.scene.layouts.diff_1').Diff1
    local with_layout = FileEntry.with_layout

    FileEntry.with_layout = function(layout_class, opt)
      local entry = with_layout(layout_class, opt)
      local added = opt.status == 'A' or opt.status == '?'
      local deleted = opt.status == 'D'
      local is_diff2 = vim.startswith(layout_class.name or '', 'diff2')

      if is_diff2 and opt.kind ~= 'conflicting' and (added or deleted) then
        entry.layout = Diff1 { b = added and entry.layout.b.file or entry.layout.a.file }
      end

      return entry
    end
  end,
}
