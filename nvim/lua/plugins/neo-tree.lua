return {
	"nvim-neo-tree/neo-tree.nvim",
	opts = {
		window = {
			-- width = 60,
		},
		sources = {
			"filesystem",
			-- "buffers",
			-- "git_status",
		},
		source_selector = {
			sources = {
				{ source = "filesystem" },
				-- { source = "buffers" },
				-- { source = "git_status" },
			},
		},
	},
}
