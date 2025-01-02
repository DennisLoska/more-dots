local largeFilesIgnoringPreviewer = function(filepath, bufnr, opts)
	local previewers = require("telescope.previewers")
	opts = opts or {}

	filepath = vim.fn.expand(filepath)
	vim.loop.fs_stat(filepath, function(_, stat)
		if not stat then
			return
		end
		if stat.size > 100000 then
			return
		else
			previewers.buffer_previewer_maker(filepath, bufnr, opts)
		end
	end)
end

return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		{
			"nvim-telescope/telescope-live-grep-args.nvim",
			version = "^1.0.0",
		},
	},
	config = function()
		local sorters = require("telescope.sorters")
		local telescope = require("telescope")
		local lga_actions = require("telescope-live-grep-args.actions")

		telescope.setup({
			defaults = {
				buffer_previewer_maker = largeFilesIgnoringPreviewer,
				wrap_results = true,
				file_ignore_patterns = {
					"node_modules",
					"build",
					"dist",
					"yarn.lock",
					"tags",
					".git",
				},
				path_display = {
					filename_first = {
						reverse_directories = true,
					},
				},
			},
			pickers = {
				oldfiles = { initial_mode = "normal", sorter = sorters.fuzzy_with_index_bias() },
				command_history = { sorter = sorters.fuzzy_with_index_bias() },
				find_files = {
					hidden = true,
					mappings = {
						n = { ["kj"] = "close" },
					},
				},
				live_grep = {
					hidden = true,
					mappings = {
						n = { ["kj"] = "close" },
					},
					vimgrep_arguments = {
						"rg",
						"--follow", -- Follow symbolic links
						"--hidden", -- Search for hidden files
						"--no-heading", -- Don't group matches by each file
						"--with-filename", -- Print the file path with the matched lines
						"--line-number", -- Show line numbers
						"--column", -- Show column numbers
						"--smart-case", -- Smart case search

						-- Exclude some patterns from search
						"--glob=!**/.git/*",
						"--glob=!**/.idea/*",
						"--glob=!**/.vscode/*",
						"--glob=!**/build/*",
						-- "--glob=!**/node_modules/*",
						"--glob=!**/dist/*",
						"--glob=!**/yarn.lock",
						"--glob=!**/package-lock.json",
						"--glob=!**/tags",
					},
				},
				git_files = { show_untracked = true, wrap_results = true },
			},
			extensions = {
				auto_quoting = true, -- enable/disable auto-quoting
				-- define mappings, e.g.
				mappings = { -- extend mappings
					i = {
						["<C-k>"] = lga_actions.quote_prompt(),
						["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
						-- freeze the current list and start a fuzzy search in the frozen list
						["<C-space>"] = lga_actions.to_fuzzy_refine,
					},
				},
			},
		})

		telescope.load_extension("live_grep_args")
	end,
}
