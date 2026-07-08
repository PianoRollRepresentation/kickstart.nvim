-- askai — mark text in Neovim and ask GitHub Copilot CLI a question about it.
--
-- Select text in visual mode and press <leader>aa (or run :AskAI). The answer
-- streams into a floating window; press i/a/<CR> to ask follow-ups, q to close.
--
-- This file is loaded by lazy.nvim as a spec source: it configures itself on
-- load and returns an empty spec list.

local M = {}

local defaults = {
  -- Executable + base flags for the GitHub Copilot CLI.
  cmd = 'copilot',
  -- Read-only, non-interactive access: allow only file view/search tools (no
  -- edit/create/shell), so the CLI can read files but never modify anything.
  args = {
    '--no-color',
    '--log-level',
    'none',
    '--no-custom-instructions',
    '--allow-all-paths',
    '--available-tools',
    'view',
    '--available-tools',
    'grep',
    '--available-tools',
    'glob',
    '--allow-tool',
    'view',
    '--allow-tool',
    'grep',
    '--allow-tool',
    'glob',
  },
  -- AI model and reasoning effort. Set either to false to use the CLI default.
  model = 'claude-sonnet-5',
  effort = 'low',
  -- Working directory for the CLI. Defaults to Neovim's current directory so
  -- the model can resolve files relative to your session. Set to a fixed path
  -- to override, or false to inherit the raw process directory.
  cwd = nil,
  -- Hard timeout in milliseconds before the request is aborted.
  timeout = 120000,
  -- Extra instruction prepended so the model answers instead of editing files.
  system_prompt = 'You are answering a question about a text selection taken '
    .. 'from an editor buffer. Answer the question directly and concisely in '
    .. 'Markdown. Do NOT modify any files or run any commands.',
  -- Floating window sizing (fraction of the editor).
  width = 0.6,
  height = 0.6,
  -- Default keymap for visual mode (set to false/'' to disable).
  keymap = '<leader>aa',
}

M.config = vim.deepcopy(defaults)

--- Return the currently selected text as a single string (works in visual mode).
local function get_visual_selection()
  local mode = vim.fn.mode()
  local region_type = mode
  if mode == '\22' then -- CTRL-V, blockwise
    region_type = 'b'
  elseif mode ~= 'v' and mode ~= 'V' then
    -- Not in visual mode: fall back to the last selection marks.
    local ok, lines = pcall(vim.fn.getregion, vim.fn.getpos "'<", vim.fn.getpos "'>", { type = vim.fn.visualmode() })
    if ok and lines and #lines > 0 then
      return table.concat(lines, '\n')
    end
    return nil
  end

  local lines = vim.fn.getregion(vim.fn.getpos 'v', vim.fn.getpos '.', { type = region_type })
  if not lines or #lines == 0 then
    return nil
  end
  return table.concat(lines, '\n')
end

--- Open a scratch floating window and return (buf, win).
local function open_float(title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'wipe'

  local width = math.floor(vim.o.columns * M.config.width)
  local height = math.floor(vim.o.lines * M.config.height)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. (title or 'Ask AI') .. ' ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  -- Close with q / <Esc>.
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end

  return buf, win
end

--- Replace the whole buffer with the given multi-line string.
local function set_buf_text(buf, text)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local lines = vim.split(text, '\n', { plain = true })
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

--- Build the full prompt sent to the CLI.
local function build_prompt(question, selection, filetype)
  local ft = (filetype ~= nil and filetype ~= '') and filetype or ''
  return table.concat({
    M.config.system_prompt,
    '',
    'Question: ' .. question,
    '',
    'Selected text' .. (ft ~= '' and (' (' .. ft .. ')') or '') .. ':',
    '```' .. ft,
    selection,
    '```',
  }, '\n')
end

--- Greedy word-wrap to a display width.
local function wrap(text, width)
  local out, line = {}, ''
  for word in text:gmatch '%S+' do
    if line == '' then
      line = word
    elseif vim.fn.strdisplaywidth(line .. ' ' .. word) <= width then
      line = line .. ' ' .. word
    else
      table.insert(out, line)
      line = word
    end
  end
  if line ~= '' then
    table.insert(out, line)
  end
  if #out == 0 then
    out = { '' }
  end
  return out
end

--- Build the fixed header: the question followed by the quoted selection,
--- all inside a bordered input box (like the Copilot CLI prompt).
--- For follow-up turns `selection` is nil/empty, so only the question is shown.
local function build_header(question, selection, _filetype)
  local maxw = math.max(30, math.floor(vim.o.columns * M.config.width) - 6)
  local text = question
  if selection and selection ~= '' then
    local flat = selection:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    text = question .. ' "' .. flat .. '"'
  end
  local qlines = wrap(text, maxw - 2) -- room for the "> " prefix

  local inner = 0
  for i, l in ipairs(qlines) do
    local prefix = (i == 1) and '> ' or '  '
    inner = math.max(inner, vim.fn.strdisplaywidth(prefix .. l))
  end
  inner = math.min(math.max(inner, 10), maxw)

  local lines = { '╭' .. string.rep('─', inner + 2) .. '╮' }
  for i, l in ipairs(qlines) do
    local s = ((i == 1) and '> ' or '  ') .. l
    local pad = inner - vim.fn.strdisplaywidth(s)
    table.insert(lines, '│ ' .. s .. string.rep(' ', math.max(0, pad)) .. ' │')
  end
  table.insert(lines, '╰' .. string.rep('─', inner + 2) .. '╯')
  table.insert(lines, '')
  return lines
end

--- Write the transcript plus any transient extra lines into the buffer and
--- keep the view scrolled to the bottom (terminal-like).
local function write_buffer(state, extra)
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local lines = vim.deepcopy(state.lines)
  if extra then
    vim.list_extend(lines, extra)
  end
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  if vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_set_cursor, state.win, { #lines, 0 })
  end
end

local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local HINT = '─── press i to ask a follow-up • q to close ───'

--- Strip the leading "● Disabled tools: ..." notice the CLI prints when tools
--- are restricted. The block may wrap over several indented lines and ends at
--- the first blank line. While it is still streaming (no blank line yet), hide
--- it entirely so it never flashes on screen.
local function clean_answer(s)
  if s:match '^%s*●%s*Disabled tools:' then
    local rest = s:match '^%s*●%s*Disabled tools:.-\n%s*\n(.*)$'
    return rest or ''
  end
  return s
end

--- Run one CLI turn: commit the header, stream the answer, then finalize.
--- Resumes the previous session when `state.session_id` is set.
local function run_turn(state, header, prompt)
  state.busy = true
  vim.list_extend(state.lines, header)

  local start = vim.uv.now()
  local answer, stderr_acc = '', ''
  local finished = false

  local function render()
    local i = (math.floor((vim.uv.now() - start) / 100) % #spinner_frames) + 1
    local secs = math.floor((vim.uv.now() - start) / 1000)
    local shown = clean_answer(answer)
    local verb = (shown == '') and 'Thinking' or 'Generating'
    local extra = {}
    if shown ~= '' then
      vim.list_extend(extra, vim.split(shown, '\n', { plain = true }))
    end
    table.insert(extra, '')
    table.insert(extra, spinner_frames[i] .. ' ' .. verb .. '... (' .. secs .. 's)  — press q to cancel')
    write_buffer(state, extra)
  end
  render()

  local timer = vim.uv.new_timer()
  local function stop_timer()
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end
  end
  timer:start(0, 100, vim.schedule_wrap(function()
    if not finished then
      render()
    end
  end))

  local args = vim.deepcopy(M.config.args)
  if state.session_id then
    table.insert(args, '--resume=' .. state.session_id)
  end
  if M.config.model then
    table.insert(args, '--model')
    table.insert(args, M.config.model)
  end
  if M.config.effort then
    table.insert(args, '--effort')
    table.insert(args, M.config.effort)
  end
  table.insert(args, '-p')
  table.insert(args, prompt)

  local cmd = { M.config.cmd }
  vim.list_extend(cmd, args)

  local sys_opts = {
    text = true,
    stdout = function(_, data)
      if data and data ~= '' then
        answer = answer .. data
        vim.schedule(render)
      end
    end,
    stderr = function(_, data)
      if data and data ~= '' then
        stderr_acc = stderr_acc .. data
      end
    end,
  }
  local cwd = M.config.cwd
  if cwd == nil then
    cwd = vim.fn.getcwd() -- honor :cd/:lcd/:tcd of the current session
  end
  if cwd then
    sys_opts.cwd = cwd
  end
  if M.config.timeout and M.config.timeout > 0 then
    sys_opts.timeout = M.config.timeout
  end

  local ok, handle = pcall(vim.system, cmd, sys_opts, function(obj)
    vim.schedule(function()
      finished = true
      stop_timer()
      state.handle = nil

      local id = stderr_acc:match '%-%-resume=([0-9a-fA-F-]+)'
      if id then
        state.session_id = id
      end

      answer = clean_answer(answer):gsub('%s+$', '')
      local commit
      if answer ~= '' then
        commit = vim.split(answer, '\n', { plain = true })
      else
        local killed = obj.signal and obj.signal ~= 0
        commit = { '⚠️ No answer' .. (killed and ' (timed out / killed)' or '') .. '. Exit code: ' .. tostring(obj.code) }
        local err = stderr_acc:gsub('%s+$', '')
        if err ~= '' then
          vim.list_extend(commit, { '', '```' })
          vim.list_extend(commit, vim.split(err, '\n', { plain = true }))
          table.insert(commit, '```')
        end
      end
      vim.list_extend(state.lines, commit)
      table.insert(state.lines, '')
      state.busy = false
      write_buffer(state, { HINT })
    end)
  end)

  if not ok then
    stop_timer()
    state.busy = false
    vim.list_extend(state.lines, { '⚠️ Failed to start `' .. M.config.cmd .. '`:', tostring(handle), '' })
    write_buffer(state, { HINT })
    return
  end

  state.handle = handle
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(state.win),
    once = true,
    callback = function()
      stop_timer()
      if state.handle then
        pcall(function()
          state.handle:kill 'sigterm'
        end)
      end
    end,
  })
end

--- Prompt for a follow-up question and run it in the same session.
local function ask_followup(state)
  if state.busy then
    vim.notify('askai: still generating, please wait', vim.log.levels.WARN)
    return
  end
  vim.schedule(function()
    vim.ui.input({ prompt = 'Follow-up: ' }, function(q)
      if not q or q == '' then
        return
      end
      run_turn(state, build_header(q, nil, nil), q)
    end)
  end)
end

--- Ask a question about the current visual selection.
function M.ask()
  local selection = get_visual_selection()
  if not selection or selection == '' then
    vim.notify('askai: no text selected', vim.log.levels.WARN)
    return
  end
  local filetype = vim.bo.filetype

  -- Leave visual mode synchronously so the <Esc> does not land in the
  -- typeahead and cancel the upcoming input prompt.
  if vim.fn.mode():match '[vV\22]' then
    vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, false, true))
  end

  -- Defer the prompt to the next tick so the cmdline is clean.
  vim.schedule(function()
    vim.ui.input({ prompt = 'Ask AI about selection: ' }, function(question)
      if not question or question == '' then
        return
      end

      local buf, win = open_float 'Ask AI'
      local state = { buf = buf, win = win, lines = {}, session_id = nil, busy = false }

      -- Follow-up keymaps, active in the float.
      for _, key in ipairs { 'i', 'a', '<CR>' } do
        vim.keymap.set('n', key, function()
          ask_followup(state)
        end, { buffer = buf, nowait = true, silent = true, desc = 'Ask a follow-up' })
      end

      local prompt = build_prompt(question, selection, filetype)
      run_turn(state, build_header(question, selection, filetype), prompt)
    end)
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})

  vim.api.nvim_create_user_command('AskAI', function()
    M.ask()
  end, { range = true, desc = 'Ask Copilot CLI about the selected text' })

  if M.config.keymap and M.config.keymap ~= '' then
    vim.keymap.set('x', M.config.keymap, function()
      M.ask()
    end, { desc = 'Ask AI about selection', silent = true })
  end
end

-- Wire it up. This file is a lazy.nvim spec source, so configure on load and
-- return an empty spec list (there is no external plugin to manage).
M.setup {
  -- keymap = '<leader>aa',     -- visual-mode mapping ('' to disable)
  -- model = 'claude-sonnet-5', -- or false to use the CLI default
  -- effort = 'low',            -- none|minimal|low|medium|high|xhigh|max, or false
  -- cwd = nil,                 -- nil = Neovim's cwd; set a path to override
  -- timeout = 120000,          -- ms before the request is aborted
  -- width = 0.6, height = 0.6,
}

return {}
