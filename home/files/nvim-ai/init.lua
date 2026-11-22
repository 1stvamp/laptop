-- ~/.config/nvim-ai/init.lua
-- Isolated AI-focused Neovim config. Launch with:
--   NVIM_APPNAME=nvim-ai neovide
--   NVIM_APPNAME=nvim-ai nvim
-- Your classic ~/.vimrc and ~/.config/nvim stay untouched.
-- Requires Neovim 0.11+ (for vim.lsp.config / vim.lsp.enable).

-- NOTE: leader is Space here. Your old config used the default leader (\).
-- Set this to "\\" if your fingers expect that.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

--------------------------------------------------------------------------------
-- Global options (migrated from your .vimrc)
--------------------------------------------------------------------------------

vim.opt.smartindent = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.infercase = true
vim.opt.scrolloff = 3
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.number = true
vim.opt.relativenumber = true -- (my addition; remove if unwanted)
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.completeopt = "longest,menuone"
vim.opt.wildmenu = true
vim.opt.wildmode = "list:longest,full"
vim.opt.showcmd = true -- pending keys in the command area
vim.opt.timeoutlen = 1200 -- 1000 default + which-key's 200ms popup delay
vim.opt.history = 1000
vim.opt.foldlevel = 99
vim.opt.belloff = "all"
vim.opt.listchars = { tab = ">-", eol = "$" }
vim.opt.shortmess:append("I")
vim.opt.clipboard = ""
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("state") .. "/undo"
vim.opt.mouse = vim.g.neovide and "a" or ""

vim.g.python_highlight_all = 1

-- Dropped on purpose (obsolete or default in Neovim):
--   nocompatible, backspace=..., fixdel, set <del>, matchit runtime -> defaults
--   pastetoggle=<F2> -> Neovim auto-detects bracketed paste
--   clientserver `Edit` command -> nvim uses --server/--remote

--------------------------------------------------------------------------------
-- Keymaps (migrated)
--------------------------------------------------------------------------------

local map = vim.keymap.set
map("n", "<F1>", "<nop>")
-- K reclaimed for LSP hover (set in LspAttach); falls back to keywordprg elsewhere
map({ "n", "v", "o" }, "Q", "gq", { desc = "Format" })
map("n", "Y", "y$")
map("n", "<leader><space>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "<F4>", [[:%s/\r$//g<cr>]], { desc = "Strip trailing CRs" })
map("n", "<F7>", "<cmd>bd<cr>", { desc = "Delete buffer" })
map("n", "<F8>", "<cmd>bp<cr>", { desc = "Previous buffer" })
map("n", "<F9>", "<cmd>bn<cr>", { desc = "Next buffer" })
map("n", "\\", [[<Esc>:set noignorecase<cr><cr>/<Right>]], { desc = "Case-sensitive search" })

vim.cmd([[cnoremap w!! execute 'silent! write !sudo tee % >/dev/null' <bar> edit!]])
vim.api.nvim_create_user_command("W", "w !sudo tee % > /dev/null", {})

--------------------------------------------------------------------------------
-- Bad whitespace flagging (migrated)
--------------------------------------------------------------------------------

vim.api.nvim_set_hl(0, "BadWhitespace", { bg = "red" })
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "ruby", "terraform" },
  callback = function()
    vim.fn.matchadd("BadWhitespace", "^\\t\\+")
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "c", "cpp" },
  callback = function()
    vim.fn.matchadd("BadWhitespace", "\\s\\+$")
  end,
})

--------------------------------------------------------------------------------
-- Per-language indent / width (migrated)
--------------------------------------------------------------------------------

local ft_settings = {
  python = { expandtab = true, shiftwidth = 4, tabstop = 8, textwidth = 79 },
  ruby = { expandtab = true, shiftwidth = 2 },
  typescript = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  typescriptreact = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  javascript = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  javascriptreact = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  json = { expandtab = true, shiftwidth = 4, tabstop = 4 },
  yaml = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  terraform = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  hcl = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  css = { expandtab = true, shiftwidth = 4 },
  html = { expandtab = true, shiftwidth = 4 },
  xml = { expandtab = true, shiftwidth = 4 },
  php = { expandtab = false, shiftwidth = 4, tabstop = 4 },
  c = { expandtab = false, shiftwidth = 8, tabstop = 8, textwidth = 79 },
  cpp = { expandtab = false, shiftwidth = 8, tabstop = 8, textwidth = 79 },
  go = { expandtab = false, shiftwidth = 4, tabstop = 4, softtabstop = 4 },
  kdl = { expandtab = true, shiftwidth = 2, tabstop = 4 },
  coffee = { expandtab = true, tabstop = 4 },
  lua = { expandtab = true, shiftwidth = 2, tabstop = 2 },
  make = { expandtab = false },
}
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    local s = ft_settings[args.match]
    if not s then
      return
    end
    for k, v in pairs(s) do
      vim.bo[args.buf][k] = v
    end
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.bo.formatoptions = vim.bo.formatoptions:gsub("[cor]", "")
  end,
})
vim.filetype.add({ extension = { kdl = "kdl", prisma = "prisma" } })

-- Go run/build/test under the <leader>r run group. Implements is `gi`,
-- info/doc is `K` (hover), so no Go-specific intelligence maps are needed.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    map("n", "<leader>rr", "<cmd>!go run .<cr>", { buffer = true, desc = "Go: run" })
    map("n", "<leader>rb", "<cmd>!go build ./...<cr>", { buffer = true, desc = "Go: build" })
    map("n", "<leader>rt", "<cmd>!go test ./...<cr>", { buffer = true, desc = "Go: test" })
    map("n", "<leader>rc", "<cmd>!go test -cover ./...<cr>", { buffer = true, desc = "Go: coverage" })
  end,
})

--------------------------------------------------------------------------------
-- Neovide GUI: clipboard + AI key combos
--------------------------------------------------------------------------------

if vim.g.neovide then
  vim.o.guifont = "Maple Mono NF,monospace:h13" -- Nerd Font build; icons included
  vim.g.neovide_cursor_animation_length = 0.05
  vim.g.neovide_scroll_animation_length = 0.2
  vim.g.neovide_remember_window_size = true

  map({ "n", "v" }, "<C-S-c>", '"+y', { desc = "Copy to clipboard" })
  map("v", "<C-S-x>", '"+d', { desc = "Cut to clipboard" })
  map("n", "<C-S-v>", '"+p', { desc = "Paste from clipboard" })
  map("i", "<C-S-v>", "<C-r>+", { desc = "Paste from clipboard" })
  map("c", "<C-S-v>", "<C-r>+", { desc = "Paste from clipboard" })
  map("t", "<C-S-v>", [[<C-\><C-n>"+pi]], { desc = "Paste in terminal" })
  map("n", "<C-S-a>", "ggVG", { desc = "Select all" })
  map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr>", { desc = "Save" })
  map("v", "<C-S-l>", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
  map({ "n", "i", "t" }, "<C-S-k>", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude Code" })

  -- Alternative MacVim Cmd port via Super key (uncomment; DEs may grab Super):
  -- vim.g.neovide_input_use_logo = true
  -- map("v", "<D-c>", '"+y'); map("v", "<D-x>", '"+d')
  -- map("n", "<D-v>", '"+p'); map("i", "<D-v>", "<C-r>+")
  -- map("n", "<D-a>", "ggVG"); map("v", "<D-l>", "<cmd>ClaudeCodeSend<cr>")
end

--------------------------------------------------------------------------------
-- Plugins
--------------------------------------------------------------------------------

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
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

require("lazy").setup({
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  -- Syntax highlighting (replaces vim syntax, python_highlight_all, go highlights)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
      ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "bash",
        "python",
        "ruby",
        "rust",
        "go",
        "c",
        "cpp",
        "php",
        "typescript",
        "javascript",
        "tsx",
        "json",
        "jsonc",
        "yaml",
        "toml",
        "hcl",
        "terraform",
        "css",
        "html",
        "xml",
        "markdown",
        "markdown_inline",
        "prisma",
        "sql",
        "dockerfile", -- Trigger.dev stack
      },
    },
  },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern", -- try "helix" or "classic" if you prefer
      delay = 200, -- ms after a prefix before the popup appears
      spec = {
        { "<leader>a", group = "AI / Claude" },
        { "<leader>c", group = "code" },
        { "<leader>f", group = "find" },
        { "<leader>p", group = "project (Trigger.dev)" },
        { "<leader>r", group = "run" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer-local keymaps",
      },
    },
  },

  -- Fuzzy finder (replaces CtrlP: ; = buffers, ~ = lines in buffer)
  {
    "folke/snacks.nvim",
    priority = 1000,
    opts = {
      picker = { enabled = true },
      bigfile = { enabled = true },
    },
    keys = {
      {
        "<leader>ff",
        function()
          Snacks.picker.files()
        end,
        desc = "Find files",
      },
      {
        "<leader>fg",
        function()
          Snacks.picker.grep()
        end,
        desc = "Grep",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
      },
      {
        "<leader>fl",
        function()
          Snacks.picker.lines()
        end,
        desc = "Lines in buffer",
      },
      -- CtrlP-style aliases (your muscle memory)
      {
        ";",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers (CtrlP alias)",
      },
      {
        "~",
        function()
          Snacks.picker.lines()
        end,
        desc = "Lines (CtrlP alias)",
      },
      -- Trigger.dev monorepo scope (<leader>p = project). Run nvim from repo root.
      {
        "<leader>pa",
        function()
          Snacks.picker.files({ cwd = "apps" })
        end,
        desc = "Files in apps/",
      },
      {
        "<leader>pp",
        function()
          Snacks.picker.files({ dirs = { "packages", "internal-packages" } })
        end,
        desc = "Files in packages/",
      },
      {
        "<leader>pe",
        function()
          Snacks.picker.grep({ dirs = { "internal-packages/run-engine" } })
        end,
        desc = "Grep the run engine",
      },
      {
        "<leader>pw",
        function()
          Snacks.picker.grep({ dirs = { "apps/webapp" } })
        end,
        desc = "Grep the webapp",
      },
      {
        "<leader>ps",
        function()
          vim.cmd("edit internal-packages/database/prisma/schema.prisma")
        end,
        desc = "Open Prisma schema",
      },
      {
        "<leader>pS",
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = "Workspace symbols",
      },
    },
  },

  -- Symbol outline (replaces Tagbar: <F10>)
  {
    "stevearc/aerial.nvim",
    opts = {},
    keys = { { "<F10>", "<cmd>AerialToggle<cr>", desc = "Symbol outline (was Tagbar)" } },
  },

  -- OPTIONAL: Telescope, if you specifically want it over the snacks picker.
  -- Heads-up: telescope-fzf-native needs a C build (make/cc) at install time,
  -- which is the kind of thing that fails the morning of a trial. The snacks
  -- pickers above already cover files/grep/symbols with ripgrep and no build,
  -- so only add this if you have a reason to. Uncomment to enable.
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   branch = "0.1.x",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim",
  --     { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  --   },
  --   opts = {
  --     defaults = {
  --       -- ripgrep, ignoring build/generated noise on top of .gitignore
  --       file_ignore_patterns = { "node_modules", "%.turbo", "dist", "build", "%.next" },
  --       vimgrep_arguments = {
  --         "rg", "--color=never", "--no-heading", "--with-filename",
  --         "--line-number", "--column", "--smart-case", "--hidden",
  --         "--glob", "!**/.git/*",
  --       },
  --     },
  --   },
  --   config = function(_, opts)
  --     require("telescope").setup(opts)
  --     pcall(require("telescope").load_extension, "fzf")
  --   end,
  -- },

  -- Completion (replaces jedi's completion half)
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = {
        preset = "enter", -- Enter accepts
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },

  -- LSP: diagnostics + intelligence (replaces syntastic + jedi + vim-go intel)
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      require("mason").setup()

      vim.diagnostic.config({ virtual_text = true, severity_sort = true })

      -- blink.cmp capabilities, applied to every server (Neovim 0.11 model)
      local ok, blink = pcall(require, "blink.cmp")
      if ok then
        vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities() })
      end

      -- Per-server overrides (merged onto nvim-lspconfig's base configs)
      vim.lsp.config("lua_ls", {
        settings = { Lua = { diagnostics = { globals = { "vim" } } } },
      })
      vim.lsp.config("gopls", {
        settings = { gopls = { gofumpt = true, analyses = { unusedparams = true } } },
      })

      -- vtsls tuned for a large pnpm-workspaces monorepo (Trigger.dev).
      -- It finds the right tsconfig per package from one server instance, so
      -- cross-package go-to-definition resolves without spawning many servers.
      vim.lsp.config("vtsls", {
        settings = {
          typescript = {
            -- Raise if you have the RAM; lower to 4096 if memory-constrained.
            tsserver = { maxTsServerMemory = 8192 },
            -- Inlay hints off by default; they add latency on big projects.
            inlayHints = {
              parameterNames = { enabled = "none" },
              variableTypes = { enabled = false },
            },
          },
          vtsls = {
            autoUseWorkspaceTsdk = true, -- use the repo's TypeScript version
            experimental = {
              completion = { enableServerSideFuzzyMatch = true },
            },
          },
        },
        -- Deliberately NOT enabling project-wide diagnostics
        -- (typescript.tsserver.experimental.enableProjectDiagnostics): it
        -- re-checks the whole workspace and will hammer CPU on this repo.
      })

      -- mason-lspconfig v2 auto-enables installed servers via vim.lsp.enable
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "basedpyright",
          "gopls",
          "terraformls",
          "vtsls",
          "prismals",
          "bashls",
          "yamlls",
          "jsonls",
          "rust_analyzer",
          "ruby_lsp", -- needs a ruby toolchain present; drop if it fails
          -- NOTE: vtsls REPLACES ts_ls. Never enable both at once.
        },
      })

      -- LSP keymaps (Neovim 0.11 already provides grn/gra/grr/gri; these add more)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local b = { buffer = ev.buf }
          map("n", "gd", vim.lsp.buf.definition, b)
          map("n", "gD", vim.lsp.buf.declaration, b)
          map("n", "gr", vim.lsp.buf.references, b)
          map("n", "gi", vim.lsp.buf.implementation, b)
          map("n", "K", vim.lsp.buf.hover, b) -- reclaimed for hover
          map("n", "<leader>cr", vim.lsp.buf.rename, b) -- code: rename
          map("n", "<leader>ca", vim.lsp.buf.code_action, b) -- code: action
          map("n", "<leader>cd", vim.diagnostic.open_float, b) -- code: diagnostics
          map("n", "[d", function()
            vim.diagnostic.jump({ count = -1 })
          end, b)
          map("n", "]d", function()
            vim.diagnostic.jump({ count = 1 })
          end, b)
        end,
      })
    end,
  },

  -- Linters not covered by an LSP (replaces syntastic's external checkers)
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufWritePost", "InsertLeave" },
    config = function()
      require("lint").linters_by_ft = {
        yaml = { "yamllint" }, -- was syntastic yaml_checkers
        sh = { "shellcheck" }, -- was syntastic sh/bash checkers
        bash = { "shellcheck" },
        go = { "golangcilint" }, -- was go/golint/govet
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        callback = function()
          require("lint").try_lint()
        end,
      })
    end,
  },

  -- Formatting + format-on-save (replaces vim-prettier, vim-go fmt, terraform fmt)
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        markdown = { "prettier" },
        terraform = { "terraform_fmt" },
        hcl = { "terraform_fmt" },
        go = { "goimports" },
        lua = { "stylua" },
      },
      formatters = {
        -- Use OpenTofu instead of terraform (your g:terraform_binary_path="tofu")
        terraform_fmt = { command = "tofu" },
        -- stylua defaults to tabs; force 2 spaces (CLI args win over stylua.toml)
        stylua = { prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" } },
      },
      format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
    },
  },

  -- Installs the CLI tools the linters/formatters above need
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = {
        "yamllint",
        "shellcheck",
        "golangci-lint",
        "prettier",
        "stylua",
        "goimports",
      },
    },
  },

  -- PRIMARY: Claude Code bridge. Real `claude` CLI in a terminal, Neovim
  -- attached as the IDE. Uses your `claude /login` auth. One shared session.
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = { "ClaudeCode", "ClaudeCodeSend", "ClaudeCodeFocus", "ClaudeCodeAdd" },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude Code" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude terminal" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>aa", "<cmd>ClaudeCodeAdd<cr>", desc = "Add current file to context" },
    },
    opts = {
      -- Launch Claude with a Serena-provided system-prompt override.
      -- The $(...) is expanded by the shell when the terminal starts.
      terminal_cmd = 'claude --system-prompt="$(serena prompts print-cc-system-prompt-override)"',
    },
    -- For `claude` in your own external terminal instead of an nvim split, add
    -- `terminal = { provider = "external" }` to the opts above.
  },
}, {})
