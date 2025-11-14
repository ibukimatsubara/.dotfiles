-- =====================================================
-- Image Paste: img-clip.nvim
-- クリップボードから画像を貼り付け、assetsフォルダに保存
-- =====================================================

return {
  "HakonHarnes/img-clip.nvim",
  event = "VeryLazy",
  opts = {
    default = {
      -- 画像を保存するディレクトリ（現在のファイルからの相対パス）
      dir_path = "assets",
      -- 保存時のファイル名（日付ベース）
      file_name = "%Y-%m-%d-%H-%M-%S",
      -- 貼り付け時に自動で挿入されるテンプレート
      template = "![$CURSOR]($FILE_PATH)",
    },
    -- ドラッグ＆ドロップを有効にする
    drag_and_drop = {
      insert_mode = true,
    },
  },
  keys = {
    -- <leader>p でクリップボードから画像をペースト
    { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard" },
  },
}
