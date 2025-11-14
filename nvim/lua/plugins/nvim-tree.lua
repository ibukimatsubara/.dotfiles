-- =====================================================
-- File Explorer: nvim-tree
-- =====================================================

return {
  "nvim-tree/nvim-tree.lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  cmd = { "NvimTreeToggle", "NvimTreeFocus" }, -- コマンド実行時に遅延ロード
  keys = {
    { "<M-e>", "<cmd>NvimTreeToggle<cr>", desc = "Toggle NvimTree" },
  },
  config = function()
    require("nvim-tree").setup({
      disable_netrw = true,
      hijack_netrw = true,
      hijack_cursor = false,
      hijack_unnamed_buffer_when_opening = false,

      view = {
        width = 30,
        side = "left",
        number = false,
        relativenumber = false,
        signcolumn = "yes",
      },

      renderer = {
        add_trailing = false,
        group_empty = false,
        highlight_git = true,
        highlight_opened_files = "none",
        root_folder_modifier = ":~",
        indent_markers = {
          enable = true,
          icons = {
            corner = "└ ",
            edge = "│ ",
            none = "  ",
          },
        },
        icons = {
          webdev_colors = true,
          git_placement = "before",
          padding = " ",
          symlink_arrow = " ➛ ",
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
          glyphs = {
            default = "",
            symlink = "",
            folder = {
              arrow_closed = "",
              arrow_open = "",
              default = "",
              open = "",
              empty = "",
              empty_open = "",
              symlink = "",
              symlink_open = "",
            },
            git = {
              unstaged = "✗",
              staged = "✓",
              unmerged = "",
              renamed = "➜",
              untracked = "★",
              deleted = "",
              ignored = "◌",
            },
          },
        },
      },

      filters = {
        dotfiles = false,
        custom = { ".git", "node_modules", ".cache" },
      },

      git = {
        enable = true,
        ignore = true,
        timeout = 400,
      },

      update_focused_file = {
        enable = true,
        update_cwd = true,
        ignore_list = {},
      },

      actions = {
        use_system_clipboard = true,
        change_dir = {
          enable = true,
          global = false,
          restrict_above_cwd = false,
        },
        open_file = {
          quit_on_open = false,
          resize_window = false,
          window_picker = {
            enable = true,
            chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
            exclude = {
              filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
              buftype = { "nofile", "terminal", "help" },
            },
          },
        },
      },
    })
  end,
}
