---START INJECT winc.lua

local api, fn = vim.api, vim.fn
local M = {}

local augid

---@param border? string|table
---@return integer, integer
local border_size = function(border)
  if not border or border == '' or border == 'none' then return 0, 0 end
  if type(border) == 'string' then return 2, 2 end
  border = vim.tbl_map(function(b) return type(b) == 'table' and b[1] or b end, border)
  while #border < 8 do
    vim.list_extend(border, border)
  end
  ---@type fun(a: integer, b: integer, c: integer): integer
  local size = function(a, b, c)
    return (border[a] ~= '' or border[b] ~= '' or border[c] ~= '') and 1 or 0
  end
  return size(1, 2, 3) + size(5, 6, 7), size(3, 4, 6) + size(7, 8, 1)
end

--- @class vim.fn.screenpos.ret
--- @field row integer screen row
--- @field col integer first screen column
--- @field endcol integer last screen column
--- @field curscol integer cursor screen column

---@param cspos vim.fn.screenpos.ret cursor's screenpos
---@param win integer target window id
---@param zindex integer curosr's zindex
---@return boolean
local point_in_win = function(cspos, win, zindex)
  local ft = vim.bo[api.nvim_win_get_buf(win)].ft
  if true and (ft == 'pager' or ft == 'cmd') then return false end
  local opts = api.nvim_win_get_config(win)
  if opts.relative == '' or opts.hide or opts.external or (opts.zindex or 0) <= zindex then
    return false
  end
  local crow, ccol = cspos.row, cspos.col
  local wrow, wcol = unpack(fn.win_screenpos(win)) ---@type integer, integer
  if wrow <= 0 or wcol <= 0 then return false end
  local bh, bw = border_size(opts.border)
  local height, width = opts.height + bh, opts.width + bw
  local ret = crow >= wrow and crow < wrow + height and ccol >= wcol and ccol < wcol + width
  return ret
end

---@param wins? integer[]
local check_cursor_covered = function(wins)
  local curwin = api.nvim_get_current_win()
  local opts = api.nvim_win_get_config(curwin)
  local cursor = api.nvim_win_get_cursor(curwin)
  local spos = fn.screenpos(curwin, cursor[1], cursor[2] + 1) ---@type vim.fn.screenpos.ret
  local zindex = opts.zindex or 0
  for _, win in ipairs(wins or api.nvim_tabpage_list_wins(0)) do
    if win ~= curwin and point_in_win(spos, win, zindex) then return true end
  end
  return false
end

local orig_guicursor

---@param gcr table
---@param hl string
---@return table
local guicursor = function(gcr, hl)
  local new_gc = {}
  local found_a = false
  for _, v in ipairs(gcr) do
    if v:match('^a:') then
      found_a = true
      local s = v:gsub('(:[^%-]+%-?[^%-]*)$', '%1-' .. hl)
      table.insert(new_gc, 1, s)
    else
      new_gc[#new_gc + 1] = v
    end
  end
  if not found_a then table.insert(new_gc, 1, 'a:block-' .. hl) end
  return new_gc
end

---@type fun(x: any): integer
local asinteger = tonumber

M.enable = function()
  if augid then return end
  orig_guicursor = vim.opt.guicursor:get()

  api.nvim_set_hl(0, 'WincErrorCursor', { bg = '#ff0000', fg = '#ffffff' })
  augid = api.nvim_create_augroup('u.winc', { clear = true })
  local events = { 'WinEnter', 'WinNew', 'WinClosed', 'WinResized', 'CursorMoved' }
  api.nvim_create_autocmd(events, {
    group = augid,
    callback = function(ev)
      local wins = ev.event == 'WinResized' and { asinteger(ev.match) } or nil
      if check_cursor_covered(wins) then
        vim.opt.guicursor = guicursor(orig_guicursor, 'WincErrorCursor')
      elseif vim.opt.guicursor:get() ~= orig_guicursor then
        vim.opt.guicursor = orig_guicursor
      end
    end,
  })
end

M.disable = function()
  if not augid then return end
  api.nvim_del_augroup_by_id(augid)
  augid = nil
end

return M
