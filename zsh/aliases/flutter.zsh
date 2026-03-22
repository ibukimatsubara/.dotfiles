# Flutter aliases
alias fl='flutter'
alias flr='flutter run'
alias flrd='flutter run -d'
alias flb='flutter build'
alias flc='flutter clean'
alias flpg='flutter pub get'
alias flpu='flutter pub upgrade'
alias fld='flutter doctor'
alias flf='flutter format'
alias fla='flutter analyze'
alias flt='flutter test'
alias flg='flutter generate'

# Dart aliases
alias d='dart'
alias dr='dart run'
alias dt='dart test'
# alias df='dart format'
alias da='dart analyze'
alias dpg='dart pub get'
alias dpu='dart pub upgrade'

# iOS Simulator aliases (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias sim='open -a Simulator'
    alias sim-iphone='xcrun simctl boot "iPhone 16" && open -a Simulator'
    alias sim-ipad='xcrun simctl boot "iPad Pro 13-inch (M4)" && open -a Simulator'
    alias sim-list='xcrun simctl list devices available'
    alias sim-shutdown='xcrun simctl shutdown all'
fi