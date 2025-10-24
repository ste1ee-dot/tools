#!/bin/sh
#required:
#   fzf(fzy breaks hyprland for some reason), tac, sed, grep

#TODO: make j not show full paths but just one dir up, also add J for loops
#TODO: add peepee
#TODO: add coloring to sed
#TODO: make and quick access to compiler errors

#--------------------------------------------------------------------------------
# c - easily cd into recently accessed directories

CDHISTORY="$HOME/.cdhistory"

cd() {
  [ -f "$CDHISTORY" ] || touch "$CDHISTORY"
  command cd "$@" && echo "$PWD" >> $CDHISTORY
}

c() {
  dir=$(tac "$CDHISTORY" | sed "\|$PWD\$|d" | awk '!seen[$0]++' | fzf) || return 1
  [ -n "$dir" ] && cd "$dir"
}

#--------------------------------------------------------------------------------
# j - quickly access recently edited files via text editor
#by default it uses $EDITOR variable to find the default editor
#
#MAKE SURE TO ALIAS your editor command to 'edit'

EDITHISTORY="$HOME/.edithistory"

edit() {
  [ -f "$EDITHISTORY" ] || touch "$EDITHISTORY"

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

j() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | grep "$PWD" | fzf) || return 1
  [ -n "$file" ] && edit "$file"
}

jj() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | fzf) || return 1
  [ -n "$file" ] && edit "$file"
}

cleanup() {
  if [ -f "$CDHISTORY" ] && [ -f "$EDITHISTORY" ]; then
    tac "$CDHISTORY" | awk '!seen[$0]++' | tac > "$CDHISTORY.tmp" && mv "$CDHISTORY.tmp" "$CDHISTORY"
    tac "$EDITHISTORY" | awk '!seen[$0]++' | tac > "$EDITHISTORY.tmp" && mv "$EDITHISTORY.tmp" "$EDITHISTORY"

    tmpfile="/tmp/paths.$$"
    while IFS= read -r path; do
      [ -e "$path" ] && echo "$path" >> "$tmpfile"
    done < $CDHISTORY
    mv "$tmpfile" $CDHISTORY

    tmpfile="/tmp/paths.$$"
    while IFS= read -r path; do
      [ -e "$path" ] && echo "$path" >> "$tmpfile"
    done < $EDITHISTORY
    mv "$tmpfile" $EDITHISTORY

    return 0
  fi
  touch $CDHISTORY ; touch $EDITHISTORY
  return 1
}

clearup() {
    rm $EDITHISTORY ; touch $EDITHISTORY ; rm $CDHISTORY ; touch $CDHISTORY
}

