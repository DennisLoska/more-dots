return {
	{
		"navarasu/onedark.nvim",
		lazy = true,
		priority = 1000,
		opts = {
			--  other: 'dark', 'darker', 'cool', 'deep', 'warm', 'warmer'
			style = "cool",
			transparent = true,
		},
	},
	{
		"folke/tokyonight.nvim",
		lazy = true,
		priority = 1000,
		opts = {
			style = "night", -- other: 'storm', 'night', 'day', "moon"
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
			},
		},
	},
}
