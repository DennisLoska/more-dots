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

			-- Bye have a great time!
			vim.keymap.set("n", "<leader>qq", ":qa<CR>", { desc = "Exit" })

			-- Navigating by buffer
			vim.keymap.set("n", "L", ":bnext<CR>", { desc = "Next Buffer" })
			vim.keymap.set("n", "H", ":bprev<CR>", { desc = "Prev. Buffer" })

			-- Jump files
			vim.keymap.set("n", "<C-y>", "<C-^>")

			-- File explorer
			vim.keymap.set("n", "<leader>e", vim.cmd.Ex, { desc = "File Explorer" })
			vim.keymap.set("n", "<leader><leader>", ":Telescope find_files<CR>", { desc = "Find file" })

			-- Lazy
			vim.keymap.set("n", "<leader>l", ":Lazy<CR>", { desc = "Find file" })

			-- Better Quick List
			vim.keymap.set("n", "<C-n>", ":cnext<CR>")
			vim.keymap.set("n", "<C-p>", ":cprev<CR>")
			vim.keymap.set("n", "-", ":cdo :%s//cg")

			-- Glorious Undo
			vim.keymap.set("n", "<leader>u", "<CMD>lua require('undotree').toggle()<CR>")
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

			-- Harpoon the Moon!
			vim.keymap.set("n", "<leader>A", function()
				require("harpoon"):list():append()
			end, { desc = "Harpoon Buffer" })

			vim.keymap.set("n", "<leader>a", function()
				local harpoon = require("harpoon")
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end, { desc = "Harpoon Bookmarks" })

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
					"<leader>tc",
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
				{ "<leader>bn", ":let @+ = expand('%:t')<CR>", desc = "Copy Name" },
				{ "<leader>bp", ":let @+ = expand('%:p:~')<CR>", desc = "Copy Path" },
			}, { mode = "n" })

			-- Thanks Teej
			wk.add({
				{ "<leader>f", group = "Find" },
				{ "<leader>fe", ":Neotree toggle<CR>", desc = "Toggle Filetree" },
				{ "<leader>ff", ":Oil<CR>", desc = "File Explorer" },
				{ "<leader>fq", ":Oil ~/work/<CR>", desc = "Search Projects" },
				-- { "<leader>fl", ":Telescope live_grep<CR>", desc = "Search Grep" },
				-- { "<leader>ff", ":Telescope find_files<CR>", desc = "Search Files" },
				{
					"<leader>fw",
					require("telescope-live-grep-args.shortcuts").grep_word_under_cursor,
					desc = "Search Current Word",
				},
				{
					"<leader>fl",
					":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>",
					desc = "Search Grep With Args",
				},
				{ "<leader>fb", ":Telescope buffers<CR>", desc = "Search Buffers" },
				{ "<leader>fd", ":Telescope diagnostics<CR>", desc = "Search Diagnostics" },
				{ "<leader>fh", ":Telescope help_tags<CR>", desc = "Search Help" },
				{ "<leader>fg", ":Telescope git_files<CR>", desc = "Search Git Repository" },
				{ "<leader>fs", ":Telescope git_status<CR>", desc = "Search Git Status" },
				{ "<leader>fr", ":Telescope oldfiles<CR>", desc = "Search Recents" },
				{ "<leader>fc", ":Telescope find_files cwd=~/.config/nvim<CR>", desc = "Search Config" },
				{ "<leader>fa", ":Telescope AST_grep<CR>", desc = "Search w. AST" },
				{
					"<leader>fp",
					":Telescope find_files cwd=~/projects/doctolib/engines/phone_assistant<CR>",
					desc = "Search Phone Assistant Engine",
				},
				{
					"<leader>fm",
					":Telescope find_files cwd=~/projects/doctolib/engines/patient_messaging_pro<CR>",
					desc = "Search Patient Messaging Pro",
				},
				{
					"<leader>fo",
					":Telescope find_files cwd=~/projects/doctolib/packages/@doctolib/phone-assistant<CR>",
					desc = "Search Phone Assistant Frontend",
				},
			}, { mode = "n" })

			-- Code interactions
			wk.add({
				{ "<leader>c", group = "Code Actions" },
				{ "<leader>cm", ":Mason <CR>", desc = "Mason" },
			}, { mode = "n" })

			-- Git stuff
			wk.add({
				{ "<leader>g", group = "Git" },
				{ "<leader>gg", "<CMD>LazyGit<cr>", desc = "LazyGit" },
				{
					"<leader>gb",
					function()
						require("gitsigns").blame_line({ full = true })
					end,
					desc = "Git Blame",
				},
				{
					"<leader>gd",
					function()
						require("gitsigns").diffthis("~")
					end,
					desc = "Git Diff",
				},
				{ "<leader>gr", require("gitsigns").reset_buffer, desc = "Git Reset" },
			}, { mode = "n" })

			-- Ruby Utils
			wk.add({
				{ "<leader>r", group = "Ruby Utils" },
				-- { "<leader>rt", TODOD, desc = "Rails Tests" },
			}, { mode = "n" })

			-- Jira
			wk.add({
				{ "<leader>j", group = "Jira" },
				{ "<leader>je", "<CMD>JiraEpic<cr>", desc = "Jira Epic" },
				{ "<leader>ji", "<CMD>JiraIssues<cr>", desc = "Jira Issues" },
			}, { mode = "n" })

			-- map("n", "<leader>ghd", , "Diff This")
			-- Makes the LSP popups appear two seconds after not moving cursor
			-- in combination with the CursorHold options blow!
			vim.o.updatetime = 2000
			vim.cmd([[autocmd CursorHold * lua vim.lsp.buf.hover()]])
			-- vim.cmd([[autocmd CursorHold * lua vim.lsp.buf.signature_help()]])
		end,
	},
}
