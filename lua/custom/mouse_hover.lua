-- Mouse hover popups.
-- Rest the mouse for a moment and a small popup shows next to it:
--   * over code: the errors / warnings (diagnostics) at that spot
--   * over the left column (signs, line numbers) of a line with a breakpoint: the breakpoint state,
--     e.g. "Rejected: The breakpoint will not currently be hit. No symbols have been loaded ..."
-- The popup closes as soon as the mouse moves again.

local M = {}

local DELAY_MS = 400

local timer = vim.uv.new_timer()
local popup_win = nil
local last_key = nil

local function close_popup()
  if popup_win and vim.api.nvim_win_is_valid(popup_win) then
    vim.api.nvim_win_close(popup_win, true)
  end
  popup_win = nil
end

local severity_names = { 'Error', 'Warning', 'Info', 'Hint' }
local severity_hl = { 'DiagnosticError', 'DiagnosticWarn', 'DiagnosticInfo', 'DiagnosticHint' }

-- Breakpoint text for one line, or nil when there is no breakpoint there.
local function breakpoint_lines(buf, lnum)
  local bps_mod = package.loaded['dap.breakpoints'] -- only if nvim-dap is already loaded
  if not bps_mod then
    return nil
  end
  for _, bp in ipairs(bps_mod.get(buf)[buf] or {}) do
    if bp.line == lnum then
      local state = bp.state or {}
      local lines = {}
      if state.verified == true then
        table.insert(lines, { 'Breakpoint: OK (will be hit)', 'DiagnosticOk' })
      elseif state.verified == false then
        table.insert(lines, { 'Breakpoint: REJECTED', 'DiagnosticError' })
        if state.message and state.message ~= '' then
          table.insert(lines, { state.message, 'Normal' })
        end
      else
        table.insert(lines, { 'Breakpoint: not sent to a debugger yet (no session)', 'DiagnosticWarn' })
      end
      if bp.condition and bp.condition ~= '' then
        table.insert(lines, { 'Condition: ' .. bp.condition, 'Normal' })
      end
      if bp.logMessage and bp.logMessage ~= '' then
        table.insert(lines, { 'Log message: ' .. bp.logMessage, 'Normal' })
      end
      return lines
    end
  end
  return nil
end

-- Diagnostic text at a spot. col = nil means "the whole line" (mouse is in the left column).
local function diagnostic_lines(buf, lnum, col)
  local lines = {}
  for _, d in ipairs(vim.diagnostic.get(buf, { lnum = lnum - 1 })) do
    local end_col = (d.end_lnum and d.end_lnum > d.lnum) and math.huge or (d.end_col or d.col)
    if col == nil or (col >= d.col and col <= math.max(end_col, d.col + 1)) then
      local head = severity_names[d.severity] or 'Note'
      if d.source then
        head = head .. ' (' .. d.source .. (d.code and (' ' .. d.code) or '') .. ')'
      end
      table.insert(lines, { head .. ': ' .. d.message:gsub('\n', ' '), severity_hl[d.severity] or 'Normal' })
    end
  end
  return #lines > 0 and lines or nil
end

local function show_popup(lines)
  local text, width = {}, 1
  for _, l in ipairs(lines) do
    table.insert(text, l[1])
    width = math.max(width, vim.fn.strdisplaywidth(l[1]))
  end
  width = math.min(width, math.floor(vim.o.columns * 0.6))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  for i, l in ipairs(lines) do
    vim.hl.range(buf, vim.api.nvim_create_namespace 'mouse_hover', l[2], { i - 1, 0 }, { i - 1, -1 })
  end
  vim.bo[buf].bufhidden = 'wipe'

  popup_win = vim.api.nvim_open_win(buf, false, {
    relative = 'mouse',
    row = 1,
    col = 1,
    width = width,
    height = #text,
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    noautocmd = true,
  })
  vim.wo[popup_win].wrap = true
  -- Long lines wrap, so give the popup enough rows for them.
  local height = vim.api.nvim_win_text_height(popup_win, {}).all
  vim.api.nvim_win_set_height(popup_win, math.min(height, math.floor(vim.o.lines * 0.5)))
end

local function on_hover()
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or pos.line == 0 or pos.winid == popup_win then
    return
  end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local info = vim.fn.getwininfo(pos.winid)[1]
  local in_gutter = pos.wincol <= info.textoff

  local lines
  if in_gutter then
    lines = breakpoint_lines(buf, pos.line) or diagnostic_lines(buf, pos.line, nil)
  else
    lines = diagnostic_lines(buf, pos.line, pos.column - 1)
  end
  if lines then
    show_popup(lines)
  end
end

function M.setup()
  vim.o.mousemoveevent = true

  vim.keymap.set({ 'n', 'v' }, '<MouseMove>', function()
    local pos = vim.fn.getmousepos()
    local key = table.concat({ pos.winid, pos.line, pos.wincol }, ':')
    if key == last_key then
      return
    end
    last_key = key
    close_popup()
    timer:stop()
    timer:start(DELAY_MS, 0, vim.schedule_wrap(on_hover))
  end, { desc = 'Mouse hover popup (diagnostics / breakpoint state)' })
end

return M
