return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		local mason = require("mason")
		local mason_lspconfig = require("mason-lspconfig")
		local mason_tool_installer = require("mason-tool-installer")

		mason.setup({})

		mason_lspconfig.setup({
			ensure_installed = {
				"lua_ls",
				"html",
				"cssls",
				"denols",
				-- "ts_ls",
				"eslint",
				"golangci_lint_ls",
				"gopls",
				"templ",
				"rubocop",
				"solargraph",
				"ruby_lsp",
				"bashls",
				"yamlls",
				"terraformls",
			},
			automatic_installation = true,
		})

		mason_tool_installer.setup({
			ensure_installed = {
				"prettier",
				"prettierd",
				"rubocop",
				"stylua",
				"shellcheck",
				"shfmt",
			},
		})
	end,
}
