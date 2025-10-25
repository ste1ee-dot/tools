#!/bin/sh
#required:
#   fzf(fzy breaks hyprland for some reason), tac, sed, grep, truncate
#-------------------------------------------------------------------------------
# This was made with significant inspiration and assistance from Stian Høiland.
#Make sure to check out his github at:        https://github.com/stianhoiland
#and give him a deserved follow on twitch at: https://www.twitch.tv/stianhoiland


#-------------------------------------------------------------------------------
# c - easily cd into recently accessed directories

CDHISTORY="$HOME/.cdhistory"

cd() {
  command cd "$@" && echo "$PWD" >> "$CDHISTORY"
}

c() {
  dir=$(tac "$CDHISTORY" | \
    sed "\|$PWD\$|d" | \
    awk '!seen[$0]++' | \
    sed -r $'s,^(|.*/)(.*)$,\\1\\\x1b[33m\\2\\\x1b[0m,' | \
    fzf --ansi | \
    sed $'s/\x1b[[0-9;]*[mK]//g') || return 1
  [ -d "$dir" ] && cd "$dir"
}

#-------------------------------------------------------------------------------
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

j() {
  while true; do
    file=$(tac "$EDITHISTORY" | \
      awk '!seen[$0]++' | \
      grep "$PWD" | \
      sed "s|^$PWD/||" | \
      sed -r $'s,^(|.*/)(.*)$,\\1\\\x1b[33m\\2\\\x1b[0m,' | \
      fzf --ansi | \
      sed $'s/\x1b[[0-9;]*[mK]//g') || return 1
    [ -z "$file" ] && break;
    edit "$file"
    [ -n "$1" ] && break;
  done
}
alias J="j single"

jj() {
  while true; do
    file=$(tac "$EDITHISTORY" | \
      awk '!seen[$0]++' | \
      sed -r $'s,^(|.*/)(.*)$,\\1\\\x1b[33m\\2\\\x1b[0m,' | \
      fzf --ansi | \
      sed $'s/\x1b[[0-9;]*[mK]//g') || return 1
  [ -z "$file" ] && break;
  edit "$file"
  [ -n "$1" ] && break;
  done
}
alias JJ="jj single"

#-------------------------------------------------------------------------------
# p - instantly open last, second or third last edited file in text editor
#
#MAKE SURE YOU ALIASED your editor command to 'edit'

p() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | sed -n "1{p;q}") || return 1
  [ -f "$file" ] && edit "$file"
}
pp() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | sed -n "2{p;q}") || return 1
  [ -f "$file" ] && edit "$file"
}
ppp() {
  file=$(tac "$EDITHISTORY" | awk '!seen[$0]++' | sed -n "3{p;q}") || return 1
  [ -f "$file" ] && edit "$file"
}

#-------------------------------------------------------------------------------
# ce, cw, cn - ce filename let's you pick and jump to the errors from gcc in editor
#               cw filename does the same for warnings
#                cn filename does the same for notes
#
#MAKE SURE YOU ALIASED your editor command to 'edit'

myCC=gcc
myCFLAGS="-std=c89 -Wall -Wextra -pedantic"

ccheck() {
  if [ $# -eq 0 ]; then
    echo "You need to provide a file"
    return 1
  fi

  if [ ! -f "$1" ]; then
    echo "File does not exist"
    return 1
  fi

  case "$1" in
    *.c|*.s|*.S|*.cpp|*.cxx|*.cc) ;;
    *)
      echo "File is not a valid source file"
      return 1 ;;
  esac

  selection=$("$myCC" $myCFLAGS "$@" 2>&1 | grep -E "^[^:]+:[0-9]+:[0-9]+: $CCHECK_TYPE:" | fzf --ansi)
  if [ -n "$selection" ]; then
    IFS=':' read -r file line column _ <<< "$selection"
    edit "$file" +":call cursor($line, $column)"
  else
    echo "Compiled without $CCHECK_TYPE""s or none were selected"
  fi
}
ce() {
  CCHECK_TYPE='error'
  ccheck "$@"
}
cw() {
  CCHECK_TYPE='warning'
  ccheck "$@"
}
cn() {
  CCHECK_TYPE='note'
  ccheck "$@"
}

#-------------------------------------------------------------------------------
# cleanup - cleans up dupicates and non existing files/dirs in history files
#
#can be added to .profile so that the files get cleaned at each login

cleanup() {
  if [ -f "$CDHISTORY" ] && [ -f "$EDITHISTORY" ]; then
    tac "$CDHISTORY" | awk '!seen[$0]++' | \
      tac > "$CDHISTORY.tmp" && mv "$CDHISTORY.tmp" "$CDHISTORY"

    tac "$EDITHISTORY" | awk '!seen[$0]++' | \
      tac > "$EDITHISTORY.tmp" && mv "$EDITHISTORY.tmp" "$EDITHISTORY"

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

#-------------------------------------------------------------------------------
# clearup - completely wipes clean the history files

clearup() {
  truncate -s 0 "$CDHISTORY" "$EDITHISTORY"
}

