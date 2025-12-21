---START INJECT winc.lua

local api, fn = vim.api, vim.fn
local M = {}

local augid

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
  local wspos = fn.screenpos(win, 1, 1) ---@type vim.fn.screenpos.ret
  ---@diagnostic disable-next-line: preferred-local-alias
  local wrow, wcol = wspos.row, wspos.col
  local has_border = opts.border and opts.border ~= 'none' and opts.border ~= false
  wrow = has_border and (wrow - 1) or wrow
  wcol = has_border and (wcol - 1) or wcol
  local height = has_border and (opts.height + 2) or opts.height
  local width = has_border and (opts.width + 2) or opts.width
  local ret = crow >= wrow and crow < wrow + height and ccol >= wcol and ccol < wcol + width
  return ret
end

local check_cursor_covered = function()
  local curwin = api.nvim_get_current_win()
  local opts = api.nvim_win_get_config(curwin)
  local cursor = api.nvim_win_get_cursor(curwin)
  local spos = fn.screenpos(curwin, cursor[1], cursor[2] + 1) ---@type vim.fn.screenpos.ret
  local zindex = opts.zindex or 0
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
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
      new_gc[#new_gc + 1] = s
    else
      new_gc[#new_gc + 1] = v
    end
  end
  if not found_a then new_gc[#new_gc + 1] = 'a:block-' .. hl end
  return new_gc
end

M.enable = function()
  if augid then return end
  orig_guicursor = vim.opt.guicursor:get()

  api.nvim_set_hl(0, 'WincErrorCursor', { bg = '#ff0000', fg = '#ffffff' })
  augid = api.nvim_create_augroup('u.winc', { clear = true })
  api.nvim_create_autocmd({ 'WinEnter', 'CursorMoved', 'WinClosed' }, {
    group = augid,
    callback = function()
      if check_cursor_covered() then
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
