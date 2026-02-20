-- DEPRECATED: none-ls/null-ls is in maintenance mode and many sources have been removed
-- Replaced by conform.nvim for formatting
-- Keeping this file disabled for reference

return {
	"nvimtools/none-ls.nvim",
	enabled = false, -- DISABLED: Use conform.nvim instead
	lazy = false,
	event = { "BufReadPre", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local null_ls = require("null-ls")
		local null_ls_utils = require("null-ls.utils")
		local formatting = null_ls.builtins.formatting
		local diagnostics = null_ls.builtins.diagnostics

		-- to setup format on save
		local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

		null_ls.setup({
			root_dir = null_ls_utils.root_pattern(".null-ls-root", "Makefile", ".git", "package.json"),
			sources = {
				-- formatting.biome,
				formatting.prettierd.with({
					disabled_filetypes = {
						"markdown",
						"md",
					},
				}),
				formatting.stylua,
				formatting.shfmt,
				formatting.black,
				formatting.rubocop,
				formatting.erb_format,
				formatting.erb_lint,
				formatting.terraform_fmt,
			},
			-- configure format on save
			on_attach = function(current_client, bufnr)
				if current_client.supports_method("textDocument/formatting") then
					vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
					vim.api.nvim_create_autocmd("BufWritePre", {
						group = augroup,
						buffer = bufnr,
						callback = function()
							vim.lsp.buf.format({
								filter = function(client)
									--  only use null-ls for formatting instead of lsp server
									return client.name == "null-ls"
								end,
								bufnr = bufnr,
								formatting_options = { tabSize = 2, insertSpaces = true },
							})
						end,
					})
				end
			end,
		})
	end,
}
