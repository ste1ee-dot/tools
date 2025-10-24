#!/bin/sh
#required:
#   fzf(fzy breaks hyprland for some reason), tac

#--------------------------------------------------------------------------------
# c - easily cd into recently accessed directories
#available arguments:
#       -rd (--remove-duplicates) | removes duplicates from .cdhistory

CDHISTORY="$HOME/.cdhistory"
[ -f "$CDHISTORY" ] || touch "$CDHISTORY" 2>/dev/null

cd() { # Appends PWD to .cdhistory on every CD command
  command cd "$@" && echo "$PWD" >> $CDHISTORY
}

c() {
  if [ "$1" = "--remove-duplicates" ] || [ "$1" = "-rd" ]; then
    tac "$CDHISTORY" | awk '!seen[$0]++' | tac > "$CDHISTORY.tmp" && mv "$CDHISTORY.tmp" "$CDHISTORY"
    return 0
  fi

  dir=$(tac "$CDHISTORY" | awk '!seen[$0]++' | fzf) || return 1
  [ -n "$dir" ] && cd "$dir"
}

#--------------------------------------------------------------------------------
# j - quickly access recently edited files via text editor
#by default it uses $EDITOR variable to find the default editor
#
#MAKE SURE TO ALIAS your editor command to 'edit'
#
#available arguments:
#       -rd (--remove-duplicates) | removes duplicates from .edithistory

EDITHISTORY="$HOME/.edithistory"
[ -f "$EDITHISTORY" ] || touch "$EDITHISTORY" 2>/dev/null

edit() {
  if [ $# -gt 0 ]; then
    case "$1" in
      -*) ;; # skip it's an actual argument
      */) ;; # skip if it's a dir
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

  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | fzf) || return 1
  [ -n "$file" ] && edit "$file"
}

