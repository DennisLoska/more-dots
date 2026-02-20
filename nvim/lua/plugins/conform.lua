return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>mp",
			function()
				require("conform").format({ async = true, lsp_fallback = true })
			end,
			mode = "",
			desc = "Format buffer",
		},
	},
	opts = {
		formatters_by_ft = {
			-- Prefer local prettier (from node_modules) over prettierd (requires node in PATH)
			javascript = { "prettier", stop_after_first = true },
			javascriptreact = { "prettier", stop_after_first = true },
			typescript = { "prettier", stop_after_first = true },
			typescriptreact = { "prettier", stop_after_first = true },
			vue = { "prettier", stop_after_first = true },
			css = { "prettier", stop_after_first = true },
			scss = { "prettier", stop_after_first = true },
			html = { "prettier", stop_after_first = true },
			json = { "prettier", stop_after_first = true },
			jsonc = { "prettier", stop_after_first = true },
			yaml = { "prettier", stop_after_first = true },
			graphql = { "prettier", stop_after_first = true },
			lua = { "stylua" },
			python = { "black" },
			go = { "gofumpt", "goimports" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			zsh = { "shfmt" },
			ruby = { "rubocop" },
			eruby = { "erb_format" },
			terraform = { "terraform_fmt" },
			tf = { "terraform_fmt" },
			["terraform-vars"] = { "terraform_fmt" },
		},
		default_format_opts = {
			lsp_format = "fallback",
		},
		format_on_save = function(bufnr)
			-- Disable for certain filetypes
			local ignore_filetypes = { "markdown", "md" }
			if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
				return
			end
			-- Disable with a global or buffer-local variable
			if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
				return
			end
			return {
				timeout_ms = 3000,
				lsp_format = "fallback",
			}
		end,
		formatters = {
			shfmt = {
				prepend_args = { "-i", "2" },
			},
		},
	},
	init = function()
		-- Create commands to toggle format on save
		vim.api.nvim_create_user_command("FormatDisable", function(args)
			if args.bang then
				-- FormatDisable! will disable formatting just for this buffer
				vim.b.disable_autoformat = true
			else
				vim.g.disable_autoformat = true
			end
		end, {
			desc = "Disable autoformat-on-save",
			bang = true,
		})
		vim.api.nvim_create_user_command("FormatEnable", function()
			vim.b.disable_autoformat = false
			vim.g.disable_autoformat = false
		end, {
			desc = "Re-enable autoformat-on-save",
		})
	end,
}
