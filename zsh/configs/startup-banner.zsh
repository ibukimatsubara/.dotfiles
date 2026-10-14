# Text version of mibuki-homepage/web/public/mibuki512.png.
# Fine-dot silhouette (variant D), preserving the original proportions.
function _mibuki_panel_style() {
  local line=$1 color_enabled=$2
  REPLY=$line
  (( color_enabled )) || return 0
  local reset=$'\e[0m' cyan=$'\e[1;38;5;81m' muted=$'\e[38;5;248m'
  local green=$'\e[1;38;5;114m' gold=$'\e[1;38;5;221m' amber=$'\e[38;5;215m'
  local -a match mbegin mend
  local MATCH MBEGIN MEND
  local metric_pattern='^((DAU \([0-9/]+\)|Subscribers|Est\. / month) +)(.*)$'
  if [[ $line =~ $metric_pattern ]]; then
    local label=${match[1]} value=${match[3]} value_color=$green suffix=''
    [[ $line == 'Est. / month'* ]] && value_color=$gold
    if [[ $value == *' cached' ]]; then
      value=${value%' cached'}
      suffix=" ${amber}cached${reset}"
    fi
    [[ $value == -- ]] && value_color=$muted
    REPLY="${label}${value_color}${value}${reset}${suffix}"
  elif [[ $line == Updated* || $line == Awaiting* ]]; then
    REPLY="${muted}${line}${reset}"
  elif [[ -n $line ]]; then
    REPLY="${cyan}${line}${reset}"
  fi
}

function mibuki_banner() {
  # Leave room for the prompt, including in split terminal panes.
  (( ${COLUMNS:-80} >= 36 && ${LINES:-24} >= 18 )) || return 0

  local logo='                             ⢀⣴⣷⣄
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
     ⠈⠻⠋          ⠙⠿⠁        ⠈⠻⡿⠋'
  local -a logo_lines panel_lines
  logo_lines=("${(@f)logo}")
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mibuki-metrics"
  local panel_file="${XDG_DATA_HOME:-$HOME/.local/share}/mibuki-metrics/panel.txt"
  if [[ ${MIBUKI_METRICS:-1} != 0 && -f "$config_dir/enabled" && -r "$panel_file" ]]; then
    panel_lines=("${(@f)$(<"$panel_file")}")
  fi

  local line logo_width=0 panel_width=0
  for line in "${logo_lines[@]}"; do
    (( ${#line} > logo_width )) && logo_width=${#line}
  done
  for line in "${panel_lines[@]}"; do
    (( ${#line} > panel_width )) && panel_width=${#line}
  done
  local color_enabled=0 logo_color='' reset='' REPLY
  if [[ ${+NO_COLOR} == 0 && ${TERM:-dumb} != dumb && ${MIBUKI_BANNER_COLOR:-auto} != 0 ]]; then
    [[ -t 1 || ${MIBUKI_BANNER_COLOR:-auto} == 1 ]] && color_enabled=1
  fi
  if (( color_enabled )); then
    logo_color=$'\e[38;5;255m'
    reset=$'\e[0m'
  fi
  print
  if (( ${#panel_lines} > 0 && COLUMNS >= logo_width + 4 + panel_width )); then
    local rows=${#logo_lines} offset=0 row panel_row
    (( ${#panel_lines} > rows )) && rows=${#panel_lines}
    (( rows > ${#panel_lines} )) && offset=$(( (rows - ${#panel_lines}) / 2 ))
    for (( row = 1; row <= rows; row++ )); do
      panel_row=$(( row - offset ))
      line=''
      (( panel_row >= 1 && panel_row <= ${#panel_lines} )) && line=${panel_lines[panel_row]}
      _mibuki_panel_style "$line" "$color_enabled"
      printf '%s%-*s%s    %s\n' "$logo_color" "$logo_width" "${logo_lines[row]:-}" "$reset" "$REPLY"
    done
  else
    # In short, narrow panes, keep the metrics and the prompt visible.
    if (( ${#panel_lines} == 0 || LINES >= ${#logo_lines} + ${#panel_lines} + 4 )); then
      print -r -- "${logo_color}${logo}${reset}"
    fi
    if (( ${#panel_lines} > 0 )); then
      print
      for line in "${panel_lines[@]}"; do
        (( ${#line} > COLUMNS )) && line="${line[1,$(( COLUMNS - 3 ))]}..."
        _mibuki_panel_style "$line" "$color_enabled"
        print -r -- "$REPLY"
      done
    fi
  fi
  print
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
