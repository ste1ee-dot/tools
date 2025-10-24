#!/bin/sh
#required:
#   fzf(fzy breaks hyprland for some reason), tac, sed, grep, truncate
#--------------------------------------------------------------------------------
# This was made with significant inspiration and assistance from Stian Høiland.
# Make sure to check out his github at:        https://github.com/stianhoiland
# and give him a deserved follow on twitch at: https://www.twitch.tv/stianhoiland

#TODO: add peepee
#TODO: add coloring to sed
#TODO: make and quick access to compiler errors

#--------------------------------------------------------------------------------
# c - easily cd into recently accessed directories

CDHISTORY="$HOME/.cdhistory"

cd() {
  command cd "$@" && echo "$PWD" >> "$CDHISTORY"
}

c() {
  dir=$(tac "$CDHISTORY" | sed "\|$PWD\$|d" | awk '!seen[$0]++' | fzf) || return 1
  [ -d "$dir" ] && cd "$dir"
}

#--------------------------------------------------------------------------------
# j - quickly access recently edited files via text editor
#by default it uses $EDITOR variable to find the default editor
#
#MAKE SURE TO ALIAS your editor command to 'edit'

EDITHISTORY="$HOME/.edithistory"

edit() {
  if [ $# -gt 0 ]; then
    case "$1" in
      -*) ;;
      */) ;;
      *.) ;;
      /*) echo "$1" >> "$EDITHISTORY" ;;
      *) echo "$PWD/$1" >> "$EDITHISTORY" ;;
    esac
  fi

  command "$EDITOR" "$@"
}

J() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | grep "$PWD" | sed "s|^$PWD/||" | fzf) || return 1
  [ -f "$file" ] && edit "$file"
}

j() {
  while true; do
    file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | grep "$PWD" | sed "s|^$PWD/||" | fzf) || return 1
    [ -f "$file" ] && edit "$file"
  done
}

JJ() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | fzf) || { echo "exit code: $?" ; return 1 ;}
  #[ -f "$file" ] && edit "$file"
}

jj() {
  while true; do
    file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | fzf) || return 1
    [ -f "$file" ] && edit "$file"
  done
}

cleanup() {
  if [ -f "$CDHISTORY" ] && [ -f "$EDITHISTORY" ]; then
    tac "$CDHISTORY" | awk '!seen[$0]++' | tac > "$CDHISTORY.tmp" && mv "$CDHISTORY.tmp" "$CDHISTORY"
    tac "$EDITHISTORY" | awk '!seen[$0]++' | tac > "$EDITHISTORY.tmp" && mv "$EDITHISTORY.tmp" "$EDITHISTORY"

    tmpfile="/tmp/paths.$$"
    while IFS= read -r path; do
      [ -d "$path" ] && echo "$path" >> "$tmpfile"
    done < $CDHISTORY
    mv -f "$tmpfile" $CDHISTORY

    while IFS= read -r path; do
      [ -f "$path" ] && echo "$path" >> "$tmpfile"
    done < $EDITHISTORY
    mv -f "$tmpfile" $EDITHISTORY

    return 0
  fi
  touch "$CDHISTORY" "$EDITHISTORY"
  return 1
}

clearup() {
  truncate -s 0 "$CDHISTORY" "$EDITHISTORY"
}

