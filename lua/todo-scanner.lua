-- TODO: Add support for more file types
-- TODO: Add support for more comment patterns
-- TODO: Modularize code
-- TODO: Add support for inline todo's

local M = {}

-- Default config
local config = {
  orgmode = false, -- Default to markdown
  comment_patterns = {
    lua = { "^%s*%-%-%s*({TODO_TAG})" },
    js = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
    ts = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
    py = { "^%s*#%s*({TODO_TAG})" },
    sh = { "^%s*#%s*({TODO_TAG})" },
    c = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
    h = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
    cpp = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
    hpp = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
    rust = { "^%s*//%s*({TODO_TAG})" },
    php = { "^%s*//%s*({TODO_TAG})", "^%s*/%*%s*({TODO_TAG})" },
  },
  todo_tags = { "TODO:", "FIXME:", "HACK:", "NOTE:" },
  exclude_dirs = { "vendor", "node_modules", ".git" },
  exclude_files = { "TODO.org", "TODO.md" },
  keymap = {
    update_todos = "<leader>ut",
  }
}

local uv = vim.loop

local compiled_patterns = {}

-- Trim whitespace from the beginning and end of a string.
-- @param str string: The string to trim.
-- @return string: The trimmed string.
local function trim(str)
  return str:match("^%s*(.-)%s*$")
end

-- Compile the patterns for each file type.
-- This replaces the {TODO_TAG} placeholder with the configured todo tag.
local function compile_patterns()
  for extension, patterns in pairs(config.comment_patterns) do
    compiled_patterns[extension] = {} -- Initialize the table
    for _, base_pattern in ipairs(patterns) do
      for _, tag in ipairs(config.todo_tags) do
        local p = base_pattern:gsub("{TODO_TAG}", tag)
        table.insert(compiled_patterns[extension], p)
      end
    end
  end
end

-- Check if a line is a todo comment.
-- @param line string: The line to check.
-- @param extension string: The file extension.
-- @return boolean: Whether the line is a todo comment.
local function is_todo_comment(line, extension)
  local patterns = compiled_patterns[extension]
  if not patterns then return false end
  for _, pattern in ipairs(patterns) do
    if line:match(pattern) then
      return true
    end
  end
  return false
end


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
      if not vim.tbl_contains(config.exclude_dirs, name) then
        scan_dir(full_path, todos)
      end
    elseif type == "file" and not vim.tbl_contains(config.exclude_files, name) then
      local extension = name:match("%.([^%.]+)$")
      if extension and config.comment_patterns[extension] then
        local f = io.open(full_path, "r")
        if f then
          local line_num = 0
          for line in f:lines() do
            line_num = line_num + 1
            if is_todo_comment(line, extension) then
              local pattern = "^" .. vim.fn.getcwd():gsub("([%%%^%$%(%)%%.%[%]*%+%-%?])", "%%%1") .. "[/\\]?"
              table.insert(todos, {
                file = full_path:gsub(pattern, ""),
                line = line_num,
                text = trim(line),
              })
            end
          end
          f:close()
        end
      end
    end
  end
end

-- Format a todo comment for the todo file.
-- @param todo table: The todo comment.
-- @return string: The formatted todo comment.
local function format_todo(todo)
  if config.orgmode then
    -- Org-mode link: [[file:relative/path::line][relative/path:line - text]]
    return string.format("** TODO [[file:%s::%d][%s:%d - %s]]", todo.file, todo.line, todo.file, todo.line, todo.text)
  else
    -- Markdown link: [relative/path:line - text](relative/path#Lline)
    return string.format("- [%s:%d - %s](%s#L%d)", todo.file, todo.line, todo.text, todo.file, todo.line)
  end
end

-- Map the keybindings
local function map_keys()
  vim.api.nvim_set_keymap("n", config.keymap.update_todos, "<cmd>lua require('todo-scanner').update_todos()<CR>",
    { noremap = true, silent = true })
end

-- Upate the todo file
function M.update_todos()
  local todos = {}
  local cwd = vim.fn.getcwd()
  scan_dir(cwd, todos)

  local lines = {}
  if config.orgmode then
    table.insert(lines, "#+TITLE: TODOs")
    table.insert(lines, "#+STARTUP: content")
    table.insert(lines, "#+OPTIONS: toc:nil num:nil todo:t pri:nil tags:nil ^:nil")
    table.insert(lines, "#+TODO: TODO | DONE")
    table.insert(lines, "")
    table.insert(lines, "* TODOs")
    for _, todo in ipairs(todos) do
      table.insert(lines, format_todo(todo))
    end
  else
    table.insert(lines, "# TODOs")
    for _, todo in ipairs(todos) do
      table.insert(lines, format_todo(todo))
    end
  end

  local filename = config.orgmode and "TODO.org" or "TODO.md"
  local full_path = cwd .. '/' .. filename
  local f = io.open(full_path, "w")
  if f then
    f:write(table.concat(lines, "\n"))
    f:close()
    vim.notify("Updated " .. filename .. " with " .. tostring(#todos) .. " TODO(s).")
  else
    vim.notify("Failed to open " .. filename .. " for writing.")
  end
end

-- This sets up the plugin config
-- @param config table: The configuration options
function M.setup(user_config)
  if user_config then
    config = vim.tbl_deep_extend("force", config, user_config)
  end
  compile_patterns()
  map_keys()
end

return M
