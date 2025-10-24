#!/bin/sh
#required:
#   fzf(fzy breaks hyprland for some reason), tac, sed, grep

#TODO: make j not show full paths but just one dir up
#TODO: add coloring to sed
#TODO: clean up non existant files (moved or deleted)

#--------------------------------------------------------------------------------
# c - easily cd into recently accessed directories
#available flags:
#       -rd (--remove-duplicates) | removes duplicates from .cdhistory
#       -ch (--clear-hisotry)     | completely clears .cdhistory file

CDHISTORY="$HOME/.cdhistory"
[ -f "$CDHISTORY" ] || touch "$CDHISTORY" 2>/dev/null

cd() {
  command cd "$@" && echo "$PWD" >> $CDHISTORY
}

c() {
  if [ "$1" = "--remove-duplicates" ] || [ "$1" = "-rd" ]; then
    tac "$CDHISTORY" | awk '!seen[$0]++' | tac > "$CDHISTORY.tmp" && mv "$CDHISTORY.tmp" "$CDHISTORY"
    return 0
  fi
  if [ "$1" = "--clear-history" ] || [ "$1" = "-ch" ]; then
    rm $CDHISTORY && touch $CDHISTORY
    return 0
  fi

  dir=$(tac "$CDHISTORY" | sed "\|$PWD\$|d" | awk '!seen[$0]++' | fzf) || return 1
  [ -n "$dir" ] && cd "$dir"
}

#--------------------------------------------------------------------------------
# j - quickly access recently edited files via text editor
#by default it uses $EDITOR variable to find the default editor
#
#MAKE SURE TO ALIAS your editor command to 'edit'
#
#available flags:
#       -rd (--remove-duplicates) | removes duplicates from .edithistory
#       -ch (--clear-hisotry)     | completely clears .edithistory file

EDITHISTORY="$HOME/.edithistory"
[ -f "$EDITHISTORY" ] || touch "$EDITHISTORY" 2>/dev/null

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

j() {
  if [ "$1" = "--remove-duplicates" ] || [ "$1" = "-rd" ]; then
    tac "$EDITHISTORY" | awk '!seen[$0]++' | tac > "$EDITHISTORY.tmp" && mv "$EDITHISTORY.tmp" "$EDITHISTORY"
    return 0
  fi
  if [ "$1" = "--clear-history" ] || [ "$1" = "-ch" ]; then
    rm $EDITHISTORY && touch $EDITHISTORY
    return 0
  fi

  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | grep "$PWD" | fzf) || return 1
  [ -n "$file" ] && edit "$file"
}

jj() {
  if [ "$1" = "--remove-duplicates" ] || [ "$1" = "-rd" ]; then
    tac "$EDITHISTORY" | awk '!seen[$0]++' | tac > "$EDITHISTORY.tmp" && mv "$EDITHISTORY.tmp" "$EDITHISTORY"
    return 0
  fi
  if [ "$1" = "--clear-history" ] || [ "$1" = "-ch" ]; then
    rm $EDITHISTORY && touch $EDITHISTORY
    return 0
  fi

  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | fzf) || return 1
  [ -n "$file" ] && edit "$file"
}

