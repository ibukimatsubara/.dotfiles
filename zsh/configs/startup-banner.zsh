# Text version of mibuki-homepage/web/public/mibuki512.png.
# Fine-dot silhouette (variant D), preserving the original proportions.
function mibuki_banner() {
  # Leave room for the prompt, including in split terminal panes.
  (( ${COLUMNS:-80} >= 36 && ${LINES:-24} >= 18 )) || return 0

  print -r -- '
                             ⢀⣴⣷⣄
                           ⢀⣴⣿⣿⣿⣿⣷⣄
             ⣠⡀           ⣠⣾⣿⣿⣿⣿⣿⣿⣿⡗
           ⣠⣾⣿⣿⣦⡀       ⣠⣾⣿⣿⣿⣿⣿⣿⣿⡿⠋
         ⢀⣴⣿⣿⣿⣿⣿⣿⣦⡀   ⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⠋
        ⣴⣿⣿⣿⣿⣿⣿⣿⣿⠟  ⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁
      ⣠⣾⣿⣿⣿⣿⣿⣿⣿⠟⠁  ⣠⣾⣿⣿⣿⣿⣿⣿⣿⠟⠁
    ⢀⣼⣿⣿⣿⣿⣿⣿⣿⡿⠋  ⣠⣾⣿⣿⣿⣿⣿⣿⣿⡿⠁  ⢀⣀
  ⢀⣴⣿⣿⣿⣿⣿⣿⣿⡿⠋  ⢀⣴⣿⣿⣿⣿⣿⣿⣿⡿⠋   ⣠⣿⣿⣦⡀
  ⠺⣿⣿⣿⣿⣿⣿⣿⠟⠁   ⠻⣿⣿⣿⣿⣿⣿⣿⠏   ⢠⣾⣿⣿⣿⣿⣿⣷⡀
   ⠈⠻⣿⣿⣿⠟⠁      ⠈⢿⣿⣿⣿⠟⠁     ⠙⣿⣿⣿⣿⡿⠋
     ⠈⠻⠋          ⠙⠿⠁        ⠈⠻⡿⠋
'
}

function _mibuki_banner_precmd() {
  add-zsh-hook -d precmd _mibuki_banner_precmd
  [[ ${MIBUKI_BANNER:-1} != 0 && -z ${_MIBUKI_BANNER_SHOWN:-} ]] || return 0
  typeset -g _MIBUKI_BANNER_SHOWN=1
  mibuki_banner
}

# Show once before the first prompt. Scripts and command-mode shells stay quiet.
if [[ -o interactive && -t 1 && ${TERM:-dumb} != dumb && -z ${ZSH_EXECUTION_STRING:-} ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _mibuki_banner_precmd
fi
