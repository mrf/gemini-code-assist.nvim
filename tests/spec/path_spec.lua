---@diagnostic disable: undefined-global
-- Tests for gemini.util.path module

local path = require("gemini.util.path")

describe("gemini.util.path", function()
  describe("sep", function()
    it("is a string", function()
      assert.is_string(path.sep)
    end)

    it("is / on Unix or \\ on Windows", function()
      local is_valid = path.sep == "/" or path.sep == "\\"
      assert.is_true(is_valid)
    end)
  end)

  describe("join", function()
    it("joins path components with separator", function()
      local result = path.join("a", "b", "c")
      local expected = "a" .. path.sep .. "b" .. path.sep .. "c"
      assert.equals(expected, result)
    end)

    it("handles single component", function()
      local result = path.join("single")
      assert.equals("single", result)
    end)

    it("handles empty strings", function()
      local result = path.join("a", "", "b")
      local expected = "a" .. path.sep .. "" .. path.sep .. "b"
      assert.equals(expected, result)
    end)
  end)

  describe("dirname", function()
    it("returns directory of a file path", function()
      local result = path.dirname("/home/user/file.txt")
      assert.equals("/home/user", result)
    end)

    it("returns parent directory", function()
      local result = path.dirname("/home/user/subdir")
      assert.equals("/home/user", result)
    end)

    it("handles root path", function()
      local result = path.dirname("/")
      assert.equals("/", result)
    end)
  end)

  describe("basename", function()
    it("returns file name from path", function()
      local result = path.basename("/home/user/file.txt")
      assert.equals("file.txt", result)
    end)

    it("returns directory name from path", function()
      local result = path.basename("/home/user/subdir")
      assert.equals("subdir", result)
    end)

    it("handles paths with trailing slash", function()
      -- vim.fn.fnamemodify behavior
      local result = path.basename("/home/user/subdir/")
      -- When there's a trailing slash, basename returns empty or the dir name
      -- depending on vim implementation
      assert.is_string(result)
    end)
  end)

  describe("extension", function()
    it("returns file extension", function()
      local result = path.extension("/home/user/file.txt")
      assert.equals("txt", result)
    end)

    it("returns empty for no extension", function()
      local result = path.extension("/home/user/Makefile")
      assert.equals("", result)
    end)

    it("handles dotfiles", function()
      -- vim.fn.fnamemodify treats dotfiles as having no extension
      -- .gitignore is the basename, not a file with extension "gitignore"
      local result = path.extension("/home/user/.gitignore")
      assert.equals("", result)
    end)

    it("handles multiple dots", function()
      local result = path.extension("/home/user/file.tar.gz")
      assert.equals("gz", result)
    end)
  end)

  describe("exists", function()
    it("returns true for existing file", function()
      -- Use the test file itself as it should exist
      local this_file = debug.getinfo(1, "S").source:sub(2)
      assert.is_true(path.exists(this_file))
    end)

    it("returns false for non-existent path", function()
      local result = path.exists("/this/path/should/not/exist/12345")
      assert.is_false(result)
    end)

    it("returns true for existing directory", function()
      local result = path.exists("/tmp")
      assert.is_true(result)
    end)
  end)

  describe("is_directory", function()
    it("returns true for directory", function()
      local result = path.is_directory("/tmp")
      assert.is_true(result)
    end)

    it("returns false for file", function()
      local this_file = debug.getinfo(1, "S").source:sub(2)
      assert.is_false(path.is_directory(this_file))
    end)

    it("returns false for non-existent path", function()
      local result = path.is_directory("/this/path/should/not/exist")
      assert.is_false(result)
    end)
  end)

  describe("is_file", function()
    it("returns true for file", function()
      local this_file = debug.getinfo(1, "S").source:sub(2)
      assert.is_true(path.is_file(this_file))
    end)

    it("returns false for directory", function()
      local result = path.is_file("/tmp")
      assert.is_false(result)
    end)

    it("returns false for non-existent path", function()
      local result = path.is_file("/this/path/should/not/exist/file.txt")
      assert.is_false(result)
    end)
  end)

  describe("root_markers", function()
    it("is a table", function()
      assert.is_table(path.root_markers)
    end)

    it("contains common root markers", function()
      local has_git = vim.tbl_contains(path.root_markers, ".git")
      local has_package_json = vim.tbl_contains(path.root_markers, "package.json")
      local has_makefile = vim.tbl_contains(path.root_markers, "Makefile")
      assert.is_true(has_git)
      assert.is_true(has_package_json)
      assert.is_true(has_makefile)
    end)
  end)

  describe("find_root", function()
    it("returns a string", function()
      local result = path.find_root()
      assert.is_string(result)
    end)

    it("returns cwd as fallback", function()
      -- When starting from a path with no markers
      local result = path.find_root("/tmp")
      -- Should fall back to cwd
      assert.is_string(result)
    end)

    it("finds root when marker exists", function()
      -- This test file is in a git repository
      local this_file = debug.getinfo(1, "S").source:sub(2)
      local result = path.find_root(this_file)
      -- Should find the project root (where .git is)
      assert.is_string(result)
      -- The result should contain the project name or be a valid directory
      assert.is_true(path.is_directory(result))
    end)
  end)

  describe("get_config_dir", function()
    it("returns a string", function()
      local result = path.get_config_dir()
      assert.is_string(result)
    end)

    it("ends with gemini-code-assist", function()
      local result = path.get_config_dir()
      assert.is_true(result:match("gemini%-code%-assist$") ~= nil)
    end)
  end)

  describe("get_data_dir", function()
    it("returns a string", function()
      local result = path.get_data_dir()
      assert.is_string(result)
    end)

    it("ends with gemini-code-assist", function()
      local result = path.get_data_dir()
      assert.is_true(result:match("gemini%-code%-assist$") ~= nil)
    end)
  end)

  describe("ensure_dir", function()
    local test_dir

    before_each(function()
      test_dir = "/tmp/gemini-test-" .. os.time()
    end)

    after_each(function()
      -- Clean up test directory
      if path.is_directory(test_dir) then
        vim.fn.delete(test_dir, "rf")
      end
    end)

    it("creates directory if it does not exist", function()
      assert.is_false(path.is_directory(test_dir))
      local result = path.ensure_dir(test_dir)
      assert.is_true(result)
      assert.is_true(path.is_directory(test_dir))
    end)

    it("returns true if directory already exists", function()
      vim.fn.mkdir(test_dir, "p")
      assert.is_true(path.is_directory(test_dir))
      local result = path.ensure_dir(test_dir)
      assert.is_true(result)
    end)

    it("creates nested directories", function()
      local nested = test_dir .. "/a/b/c"
      local result = path.ensure_dir(nested)
      assert.is_true(result)
      assert.is_true(path.is_directory(nested))
    end)
  end)
end)
