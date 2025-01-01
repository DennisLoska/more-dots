return {
	{
		"folke/which-key.nvim",
		event = "VimEnter",
		opts = {},
		keys = {},
		config = function()
			local wk = require("which-key")

			-- Get the hell outta here Umlaute!
			vim.api.nvim_set_keymap("i", "ä", "[", { noremap = false, silent = true })
			vim.api.nvim_set_keymap("i", "Ä", "]", { noremap = true, silent = true })
			vim.api.nvim_set_keymap("i", "ö", "{", { noremap = false, silent = true })
			vim.api.nvim_set_keymap("i", "Ö", "}", { noremap = true, silent = true })
			vim.api.nvim_set_keymap("i", "ü", "(", { noremap = false, silent = true })
			vim.api.nvim_set_keymap("i", "Ü", ")", { noremap = true, silent = true })

			-- Bye have a great time
			vim.keymap.set("n", "<leader>qq", ":Neotree close<CR> :qa<CR>", { desc = "Exit" })

			-- Navigating by buffer
			vim.keymap.set("n", "L", ":bnext<CR>", { desc = "Next Buffer" })
			vim.keymap.set("n", "H", ":bprev<CR>", { desc = "Prev. Buffer" })

			-- File explorer
			vim.keymap.set("n", "<leader>e", vim.cmd.Ex, { desc = "File Explorer" })
			vim.keymap.set("n", "<leader><leader>", ":Telescope find_files<CR>", { desc = "Find file" })

			-- Lazy
			vim.keymap.set("n", "<leader>l", ":Lazy<CR>", { desc = "Find file" })

			-- Remap jk to <Esc> - This is so good!
			vim.api.nvim_set_keymap("i", "jk", "<Esc>", { noremap = true, silent = true })

			-- Smart rename
			vim.keymap.set("n", "<leader>rn", function()
				vim.lsp.buf.rename()
			end, { desc = "Smart rename" })

			-- Greatest remaps ever!!!
			vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste & keep default register" })
			vim.keymap.set("n", "<leader>d", '"_d', { desc = "Delete & keep register" })

			-- Move lines up and down in visual mode
			vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
			vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")

			-- Scroll half a page and stay centered
			vim.keymap.set("n", "<C-d>", "<C-d>zz")
			vim.keymap.set("n", "<C-u>", "<C-u>zz")

			-- Ohh, so good! Scroll half a page and stay centered
			vim.keymap.set("n", "o", "o<Esc>zzi")
			vim.keymap.set("n", "O", "O<Esc>zzi")

			-- Next search item and stay centered
			vim.keymap.set("n", "n", "nzzzv")
			vim.keymap.set("n", "N", "Nzzzv")

			-- When jumping to new line with 'o' you autoindent
			vim.keymap.set("n", "o", "o<Esc>cc")

			-- Disable Ex mode
			vim.keymap.set("n", "Q", "<nop>")

			-- Not yanking with 'c' and 'x'
			vim.keymap.set({ "n", "v" }, "c", '"_c')
			vim.keymap.set("n", "C", '"_C')
			vim.keymap.set({ "n", "v" }, "x", '"_x')
			vim.keymap.set("n", "X", '"_X')

			-- Function to save the current buffer without triggering any auto-commands
			local function save_without_side_effects()
				-- Use `:noautocmd` to prevent auto-commands from running
				vim.cmd("noautocmd w")
			end

			-- Save without side effects
			vim.api.nvim_set_keymap(
				"n",
				"<C-a>",
				"",
				{ noremap = true, silent = true, callback = save_without_side_effects }
			)

			-- Better Save
			vim.keymap.set("n", "<C-s>", ":w<CR>")

			-- Better marks
			-- vim.api.nvim_set_keymap("n", "<C-m>", "'", { noremap = false, silent = true })

			-- group of various custom keymaps so I can find them more easily
			wk.add({
				{ "<leader>t", group = "Toolbelt" },
				{
					"<leader>th",
					function()
						vim.cmd("nohlsearch")
					end,
					desc = "No Highlights",
				},
				{ "<leader>tr", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], desc = "Search and Replace" },
				{
					"<leader>tl",
					function()
						vim.cmd("set relativenumber!")
					end,
					desc = "Toggle Line Numbers",
				},
				{
					"<leader>tf",
					function()
						vim.lsp.buf.references()
					end,
					desc = "Find References",
				},
				{
					"<leader>tw",
					function()
						vim.cmd("set wrap!")
					end,
					desc = "Toggle Wrap",
				},
				{
					"<leader>tx",
					function()
						vim.cmd("!chmod +x %")
					end,
					desc = "Make Executable",
				},
				-- { "<leader>tt", ":", desc = "Command" },
				{
					"<leader>tm",
					function()
						vim.cmd("!ripper-tags -R --exclude=vendor")
						vim.notify = require("notify")
						vim.notify("Success: created ctags!", vim.log.levels.INFO)
					end,
					desc = "Make ctags",
				},
				{
					"<leader>tt",
					function()
						local telescope = require("telescope.builtin")
						local word = vim.fn.expand("<cword>")
						-- Run Telescope with the current word as a tag query
						telescope.tags({ only_current_buffer = true, default_text = word })
					end,
					desc = "Find all Tags",
				},
				{
					"<leader>tg",
					"<C-]>",
					desc = "Go to Tag",
				},
				{
					"<leader>ts",
					function()
						local current_buffer = vim.api.nvim_buf_get_name(0)

						if current_buffer == "" then
							print("No file name found for this buffer!")
							return
						end

						vim.cmd("!rubocop -A " .. vim.fn.fnameescape(current_buffer))
					end,
					desc = "Format w. Rubocop",
				},
				{ "<leader>tn", ":colorscheme tokyonight-night<CR>", desc = "Tokyonight Night" },
				{ "<leader>tm", ":colorscheme tokyonight-moon<CR>", desc = "Tokyonight Moon" },
				{ "<leader>td", ":colorscheme onedark<CR>", desc = "Onedark" },
				-- {
				--   "<leader>tp", vim.cmd("ChatGPT"), desc = "ChatGPT"
				-- },
			}, { mode = "n" })

			-- More intuitive keymaps for window management
			wk.add({
				{ "<leader>w", group = "Window Management" },
				{ "<leader>wv", ":vsplit<CR>", desc = "Vertical Split" },
				{ "<leader>wh", ":split<CR>", desc = "Horizontal Split" },
				{ "<leader>wd", ":wincmd q<CR>", desc = "Close Window" },
			}, { mode = "n" })

			-- All about buffers
			wk.add({
				{ "<leader>b", group = "Buffers" },
				{ "<leader>bd", ":bdelete<CR>", desc = "Delete Buffer" },
				{ "<leader>ba", ":%bd|e#<CR>", desc = "Delete All" },
			}, { mode = "n" })

			-- Thanks Teej
			wk.add({
				{ "<leader>f", group = "Find" },
				{ "<leader>fa", ":Telescope AST_grep<CR>", desc = "Search w. AST" },
				{ "<leader>fl", ":Telescope live_grep<CR>", desc = "Search Grep" },
				{ "<leader>ff", ":Telescope find_files<CR>", desc = "Search Files" },
				{ "<leader>fb", ":Telescope buffers<CR>", desc = "Search Buffers" },
				{ "<leader>fd", ":Telescope diagnostics<CR>", desc = "Search Diagnostics" },
				{ "<leader>fh", ":Telescope help_tags<CR>", desc = "Search Help" },
				{ "<leader>fe", ":Neotree toggle<CR>", desc = "Toggle Filetree" },
			}, { mode = "n" })

			wk.add({
				{ "<leader>c", group = "Code Actions" },
				{ "<leader>cm", ":Mason <CR>", desc = "Mason" },
			}, { mode = "n" })

			-- Makes the LSP popups appear two seconds after not moving cursor
			-- in combination with the CursorHold options blow!
			vim.o.updatetime = 2000
			vim.cmd([[autocmd CursorHold * lua vim.lsp.buf.hover()]])
			-- vim.cmd([[autocmd CursorHold * lua vim.lsp.buf.signature_help()]])
		end,
	},
}
