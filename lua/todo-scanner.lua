local M = {}

-- Check if org-mode is installed
local use_orgmode = false

local uv = vim.loop

-- Recursively scan a directory for files and collect todo comments.
-- @param path string: The path to the directory to scan.
-- @param todos table: The table to store the todo comments in.
local function scan_dir(dir, todos)
  local fd = uv.fs_scandir(dir)
  if not fd then return end

  while true do
    local name, type = uv.fs_scandir_next(fd)
    if not name then break end
    local full_path = dir .. '/' .. name
    if type == "directory" then
      if name ~= "vendor" and name ~= "node_modules" then
        scan_dir(full_path, todos)
      end
    elseif type == "file" then
      local f = io.open(full_path, "r")
      if f then
        local line_num = 0
        for line in f:lines() do
          line_num = line_num + 1
          -- Look for todo comments
          -- TODO: Add support for custom todo patterns
          if line:lower():find("todo") then
            table.insert(todos, {
              path = full_path,
              line = line_num,
              text = line
            })
          end
        end
        f:close()
      end
    end
  end
end

-- Upate the todo file
function M.update_todos()
  local todos = {}
  local cwd = vim.fn.getcwd()
  scan_dir(cwd, todos)

  local lines = {}
  if use_orgmode then
    table.insert(lines, "#+TITLE: TODOs")
    for _, todo in ipairs(todos) do
      table.insert(lines, string.format("* %s:%d - %s", todo.file, todo.line, todo.text))
    end
  else
    table.insert(lines, "* TODOs")
    for _, todo in ipairs(todos) do
      table.insert(lines, string.format("- %s:%d - %s", todo.file, todo.line, todo.text))
    end
  end

  local filename = use_orgmode and "TODO.org" or "TODO.md"
  local full_path = cwd .. '/' .. filename
  local f = io.open(full_path, "w")
  if f then
    f:write(table.concat(lines, "\n"))
    f:close()
    print("Updated " .. filename .. " with " .. tostring(#todos) .. " TODO(s).")
  else
    print("Failed to open " .. filename .. " for writing.")
  end
end

-- Setup the autocmds
function M.setup_autocmds()
  vim.cmd([[
    augroup TodoUpdate
    autocmd!
      autocmd BufWritePost * lua require('todo-scanner').update_todos()
      autocmd BufDelete * lua require('todo-scanner').update_todos()
    augroup END
  ]])
end

-- This sets up the plugin config
-- @param config table: The configuration options
function M.setup(config)
  if config then
    if config.orgmode then
      use_orgmode = pcall(require, 'orgmode')
    end
  end
  M.setup_autocmds()
end

return M
