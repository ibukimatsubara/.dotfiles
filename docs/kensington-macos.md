# macOSでKensingtonだけ左右クリックを反転する

追加の設定アプリを入れず、既存のHammerspoon内で動く小さなCモジュールを使う。
対象はSlimBlade ProのUSBレシーバー `047d:80d6` だけで、ペンマウス `3151:3020` と他のマウスは通常配置を保つ。
macOS標準の「副ボタンのクリック」は `Right Side` にしておく。

macOS 26.7.1 arm64 / Hammerspoon 1.1.1 / Lua 5.4.7でビルドと36ケースの変換テストが通った。
実Hammerspoonで、観測専用tapの開始・停止・GC・リロード時の解放も確認した。
状態は開発版で、実機での入力元判定とクリック操作は未検証。
確認時には両レシーバーをMac上で列挙できなかったため、自動テストの成功だけで実機対応済みとは判断しない。

## 構成

- `hammerspoon/kensington_swap.c`: 入力元の識別、左右の押下・解放・ドラッグの変換、開始・停止。
- `scripts/build-kensington-swap.sh`: 既存のApple clangとHammerspoon付属のLuaヘッダでビルド。
- `hammerspoon/init.lua`: モジュールがインストールされていれば起動する。

追加プロセスやLuaパッケージは使わない。
元のイベントの種類とボタン番号だけを書き換え、イベントの再投稿はしない。
移動、スクロール、中ボタン、追加ボタンは変換対象に含めない。

## 先に観測だけで確認する

Hammerspoonの既存のアクセシビリティ許可を使う。
新しい権限が必要になった場合は、そこで止めて確認する。

```sh
swap_build_dir=$(mktemp -d)
scripts/build-kensington-swap.sh "$swap_build_dir/kensington_swap.so"
hs -c "kensingtonprobe = assert(package.loadlib('$swap_build_dir/kensington_swap.so', 'luaopen_kensington_swap'))(); return kensingtonprobe:start(true)"
```

`start(true)` は観測専用で、入力を変更しない。
両レシーバーを接続し、Kensingtonとペンを交互に使って、左・右それぞれのクリックとドラッグを行う。

```sh
hs -c 'return hs.inspect(kensingtonprobe:status())'
```

片方ずつ操作し、その直後の値を読む。
Kensingtonでは `target` の6種類が増え、`lastVendorID=1149` / `lastProductID=32982` になることを確認する。
ペンでは `other` の6種類が増え、`lastVendorID=12625` / `lastProductID=12320` になることを確認する。
`last*` は最後に識別できた機器の値なので、`unknown` の増加も必ず見る。
入力元が不明になる、2台が同じ機器として扱われる、押下・解放・ドラッグの一部だけ数えられない場合は、反転を有効にしない。
操作していない間のカウンター0は、故障や識別失敗の証拠にはならない。
抜き差し後も同じ確認を行い、ポートや固定のRegistry IDに依存していないことを確かめる。

観測を終えるときは次を実行する。

```sh
hs -c 'kensingtonprobe:stop(); kensingtonprobe = nil; collectgarbage()'
```

## 反転を有効にする

観測が通ってから、通常の場所へビルドしてHammerspoonをリロードする。
ビルドだけでは現在の設定はリロードされない。
両ボタンを離してから実行する。

```sh
scripts/build-kensington-swap.sh
hs -c 'hs.timer.doAfter(0.1, hs.reload); return true'
```

Finderなどで、Kensingtonの左右クリック、ダブルクリック、ドラッグを確認する。
ペンとトラックパッドの通常操作、スクロール、中ボタン、Alt＋クリックの注釈操作も確認する。
イベントカウンターだけで、アプリが意図どおり動いたとは判断しない。

## 元に戻す

両ボタンを離し、生成したモジュールを検索対象から外してHammerspoonをリロードする。
macOS標準のボタン設定は変更していないため、通常配置へ戻る。

```sh
mv "$HOME/.hammerspoon/kensington_swap.so" "$HOME/.hammerspoon/kensington_swap.so.disabled"
hs -c 'hs.timer.doAfter(0.1, hs.reload); return true'
```

## テスト

リポジトリルートで実行する。
CテストはローカルのCGEventだけを変更し、デスクトップへ入力を送らない。
Luaテストは実Hammerspoonで観測専用tapの開始・停止を確認する。

```sh
kensington_test_dir=$(mktemp -d)
clang -Wall -Wextra -Werror \
  -I/Applications/Hammerspoon.app/Contents/Frameworks/LuaSkin.framework/Versions/A/Headers \
  -F/Applications/Hammerspoon.app/Contents/Frameworks \
  -framework LuaSkin -framework CoreGraphics -framework IOKit -framework CoreFoundation \
  -Wl,-rpath,/Applications/Hammerspoon.app/Contents/Frameworks \
  scripts/test-kensington-swap.c -o "$kensington_test_dir/test-swap"
"$kensington_test_dir/test-swap"
scripts/build-kensington-swap.sh "$kensington_test_dir/kensington_swap.so"
hs -c "return assert(loadfile('$PWD/scripts/test-kensington-lifecycle.lua'))('$kensington_test_dir/kensington_swap.so')"
```

## 制約

`CGEventCopyIOHIDEvent` と `IOHIDEventGetSenderID` はmacOSの非公開API。
OS更新で使えなくなる可能性があり、更新後は観測から確認し直す。
Hammerspoonを更新した場合も、付属Luaヘッダでビルドし直す。
関数がない場合は起動を失敗として返し、入力元が不明なイベントはそのまま通す。
最後に動いたマウスやプロセスIDから機器を推測しない。

停止・リロード・抜去は両ボタンを離してから行う。
押したままタップが消えた場合の解放イベントを推測して補う処理は入れていない。

## 根拠

- [Hammerspoon 1.1.1のevent tap実装](https://github.com/Hammerspoon/hammerspoon/blob/1.1.1/extensions/eventtap/libeventtap.m)
- [WebKitのCoreGraphics SPI宣言](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/PAL/pal/spi/cg/CoreGraphicsSPI.h)
- [WebKitのIOKit SPI宣言](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/PAL/pal/spi/mac/IOKitSPIMac.h)
- [Apple IOHIDEventServiceのsender設定](https://github.com/apple-oss-distributions/IOHIDFamily/blob/777ccd9698845aadf711e32d843c8c9b777431d9/IOHIDFamily/IOHIDEventService.cpp)

ペンマウスのUSB識別情報、復旧記録、Ubuntu側の設定は [sanwa-400-mawbt186.md](./sanwa-400-mawbt186.md) を参照。
