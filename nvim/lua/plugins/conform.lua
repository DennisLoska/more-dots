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
			prettier = {
				-- Use local node_modules prettier if available and supports --stdin-filepath (v3).
				-- Prettier v4 alpha removed stdin support, so we must detect and skip it.
				-- Falls back to mason's prettier (v3) which always works.
				command = function(self, ctx)
					local util = require("conform.util")
					local resolve = util.from_node_modules("prettier")
					local cmd = resolve(self, ctx)
					-- If resolve returned bare "prettier" (no local found), use mason
					if cmd == "prettier" then
						return vim.fn.expand("~/.local/share/nvim/mason/bin/prettier")
					end
					-- Local binary found — check if v4+ (no stdin support)
					-- Cache per path so we only shell out once per nvim session
					vim.g._prettier_v4_cache = vim.g._prettier_v4_cache or {}
					local cache = vim.g._prettier_v4_cache
					if cache[cmd] == nil then
						local ok, obj = pcall(vim.system, { cmd, "--version" }, { text = true })
						if ok then
							local result = obj:wait()
							local major = tonumber((result.stdout or ""):match("^(%d+)"))
							cache[cmd] = (major or 0) >= 4
						else
							cache[cmd] = false
						end
						vim.g._prettier_v4_cache = cache
					end
					if cache[cmd] then
						return vim.fn.expand("~/.local/share/nvim/mason/bin/prettier")
					end
					return cmd
				end,
			},
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
