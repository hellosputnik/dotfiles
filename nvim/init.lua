-- Set the map leader key to space.
vim.g.mapleader = " "

-- Set tab-related bindings
vim.keymap.set("n", "<leader>n", ":tabn<CR>")
vim.keymap.set("n", "<leader>p", ":tabp<CR>")
for index = 1, 9 do
  vim.keymap.set("n", "<leader>" .. index, index .. "gt")
end
vim.keymap.set("n", "<leader>0", ":tablast<CR>")

-- Keep context lines visible above and below the cursor when scrolling.
vim.opt.scrolloff = 1

-- Enable shell-like command-line completion.
vim.opt.wildmenu = true
vim.opt.wildmode = { "list", "longest" }
vim.opt.wildignore = { "*.o", "*.obj", "*.pdf" }

-- Use system clipboard.
vim.opt.clipboard = "unnamedplus"

-- Use case-insensitive search unless the query contains uppercase letters.
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.gdefault = true

-- Highlight search terms and highlight as each key is pressed.
vim.opt.hlsearch = true

-- Make the background transparent to match the terminal background and show blur.
local function clear_backgrounds()
  local clear_bg_groups = {
    "Normal", "NormalNC", "EndOfBuffer", "LineNr", "SignColumn", "Folded", "FoldColumn", "VertSplit"
  }
  for _, group in ipairs(clear_bg_groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = clear_backgrounds,
})

-- Enable rounded borders for LSP hover and diagnostics floating windows.
vim.diagnostic.config({
  float = { border = "rounded" },
})
local original_utility_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, options, ...)
  options = options or {}
  options.border = options.border or "rounded"
  return original_utility_open_floating_preview(contents, syntax, options, ...)
end

-- Enable the highlight on the cursor's current line.
vim.opt.cursorline = true

-- Enable line numbers.
vim.opt.number = true

-- Display the cursor position and display partial commands.
vim.opt.ruler = true
vim.opt.showcmd = true

-- Limit the autocompletion menu height.
vim.opt.pumheight = 10

-- Configure the default spellcheck language.
vim.opt.spelllang = "en_us"

-- Set the maximum line width to 128.
vim.opt.textwidth = 128

-- File-specific Styles.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "gitconfig", "make" },
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.tabstop = 2
  end,
})

-- Remove trailing whitespace on save, except in filetypes where it is meaningful (e.g., Markdown hard line breaks, diff or patch context).
local blacklist = { markdown = true, diff = true, patch = true, mail = true, gitcommit = true }
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    if not blacklist[vim.bo.filetype] then
      local save_cursor = vim.fn.getpos(".")
      vim.cmd([[%s/\s\+$//e]])
      vim.fn.setpos(".", save_cursor)
    end
  end,
})

-- Automatically indent new lines to match the previous line's indentation.
vim.opt.autoindent = true

-- Use 4-spaces instead of tab.
vim.opt.expandtab = true
vim.opt.shiftwidth = 4

-- Set the tab's width to 4.
vim.opt.tabstop = 4
vim.opt.softtabstop = 4

-- Display tabs and trailing whitespaces visually.
vim.opt.list = true
vim.opt.listchars = { tab = ">·", trail = "~" }

-- Configure standard backspace behavior over line breaks and indents.
vim.opt.backspace = { "eol", "indent", "start" }

-- Disable swap files and backup files.
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Automatically reload files modified outside of Vim.
vim.opt.autoread = true

-- Enable persistent undo history.
if vim.fn.has("persistent_undo") == 1 then
  vim.opt.undodir = vim.fn.expand("~/.vim/undo")
  vim.opt.undofile = true
end

-- Enable lazyredraw to prevent unnecessary redraws.
vim.opt.lazyredraw = true

-- Map Leader + h/l to switch between open buffers.
vim.keymap.set("n", "<leader>h", ":bprevious<CR>")
vim.keymap.set("n", "<leader>l", ":bnext<CR>")

-- Modern Editor Options
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.inccommand = "split"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- List of plugins to install (Comment/Uncomment lines to enable/disable)
require("lazy").setup({
  { "folke/tokyonight.nvim" },
  { "nvim-lualine/lualine.nvim" },
  { "nvim-tree/nvim-web-devicons" },
  { "nvim-lua/plenary.nvim" },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
  },
  { "folke/flash.nvim" },
  { "nvim-treesitter/nvim-treesitter", branch = "master", build = ":TSUpdate" },
  { "lewis6991/gitsigns.nvim" },
  { "stevearc/conform.nvim" },
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  { "neovim/nvim-lspconfig" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "folke/which-key.nvim", event = "VeryLazy" },
}, {})

-- Configure plugins
local has_tokyonight, tokyonight = pcall(require, "tokyonight")
if has_tokyonight then
  tokyonight.setup({
    style = "night",
    styles = {
      comments = { italic = false },
      keywords = { italic = false },
      functions = { italic = false },
      variables = { italic = false },
    },
  })
  vim.cmd("colorscheme tokyonight")
end

local has_lualine, lualine = pcall(require, "lualine")
if has_lualine then
  lualine.setup({
    options = {
      theme = "tokyonight",
      section_separators = { left = "", right = "" },
      component_separators = { left = "", right = "" },
    }
  })
end

local has_telescope, telescope = pcall(require, "telescope")
if has_telescope then
  telescope.setup({
    extensions = {
      fzf = {
        fuzzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = "smart_case",
      },
    },
  })
  pcall(telescope.load_extension, "fzf")

  local builtin = require("telescope.builtin")
  vim.keymap.set("n", "<leader>g", builtin.live_grep)
  vim.keymap.set("n", "<leader>b", builtin.buffers)
  vim.keymap.set("n", "<leader>;", builtin.commands)
  
  -- VS Code command palette (Cmd+Shift+P) and file search (Cmd+P) mappings
  vim.keymap.set({ "n", "i" }, "<D-P>", builtin.commands)
  vim.keymap.set({ "n", "i" }, "<D-p>", builtin.find_files)
end

local has_flash, flash = pcall(require, "flash")
if has_flash then
  flash.setup()
  vim.keymap.set({"n", "x", "o"}, "<leader>f", function() flash.jump() end)
  vim.keymap.set({"n", "x", "o"}, "S", function() flash.treesitter() end)
end

local has_treesitter, treesitter = pcall(require, "nvim-treesitter.configs")
if has_treesitter then
  treesitter.setup({
    ensure_installed = { "python", "lua", "vim", "vimdoc", "markdown" },
    highlight = { enable = true },
  })
end

local has_gitsigns, gitsigns = pcall(require, "gitsigns")
if has_gitsigns then
  gitsigns.setup()
end

local has_conform, conform = pcall(require, "conform")
if has_conform then
  conform.setup({
    formatters_by_ft = {
      python = { "black" },
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = true,
    },
  })
end

local has_mason, mason = pcall(require, "mason")
local has_mason_lsp, mason_lsp = pcall(require, "mason-lspconfig")
if has_mason and has_mason_lsp then
  mason.setup()
  mason_lsp.setup({
    ensure_installed = { "pyright", "ruff" }
  })

  local capabilities = {}
  local has_cmp_lsp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
  if has_cmp_lsp then
    capabilities = cmp_lsp.default_capabilities()
  end

  vim.lsp.config("pyright", { capabilities = capabilities })
  vim.lsp.config("ruff", { capabilities = capabilities })
  vim.lsp.enable("pyright")
  vim.lsp.enable("ruff")
end

local has_cmp, cmp = pcall(require, "cmp")
if has_cmp then
  cmp.setup({
    snippet = {
      expand = function(args)
        local has_luasnip, luasnip = pcall(require, "luasnip")
        if has_luasnip then
          luasnip.lsp_expand(args.body)
        end
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ["<CR>"] = cmp.mapping.confirm({ select = true }),
      ["<Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        else
          fallback()
        end
      end, { "i", "s" }),
      ["<S-Tab>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, true, true), "n")
        else
          fallback()
        end
      end, { "i", "s" }),
    }),
    sources = cmp.config.sources({
      { name = "nvim_lsp" },
    }),
  })
end

local has_which_key, which_key = pcall(require, "which-key")
if has_which_key then
  which_key.setup()
end

-- Load local plugin overrides.
local local_bundles = vim.fn.expand("~/.vimrc.bundles.local")
if vim.fn.filereadable(local_bundles) == 1 then
  vim.cmd("source " .. local_bundles)
end

-- Load local Vim overrides.
local local_vimrc = vim.fn.expand("~/.vimrc.local")
if vim.fn.filereadable(local_vimrc) == 1 then
  vim.cmd("source " .. local_vimrc)
end
