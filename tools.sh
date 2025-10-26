#!/bin/sh
#required:
#   fzf(fzy breaks hyprland for some reason), tac, sed, grep, truncate
#-------------------------------------------------------------------------------
# This was made with significant inspiration and assistance from Stian Høiland.
#Make sure to check out his github at:        https://github.com/stianhoiland
#and give him a deserved follow on twitch at: https://www.twitch.tv/stianhoiland
#
# !!! IMPORTANT: !!!
#Make sure you aliased your editor command to 'edit'!
#These tools also you $EDITOR variable so make sure that is set correctly!

#TODO: rename for browse

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
    fzf | \
    sed $'s/\x1b[[0-9;]*[mK]//g') || return 1
  [ -d "$dir" ] && cd "$dir"
}

#-------------------------------------------------------------------------------
# j - quickly access recently edited files from current directory
# jj - same but global
# J, JJ - same things without a loop
#
#by default it uses $EDITOR variable to find the default editor
#

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
      fzf | \
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
      fzf | \
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
#ADJUST FOR YOU COMPILER / EDITOR IF NEEDED

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

  selection=$("$myCC" $myCFLAGS "$@" 2>&1 | grep -E "^[^:]+:[0-9]+:[0-9]+: $CCHECK_TYPE:" | fzf)
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
# b - mini browser for your shell
#   bc - creates a new file in current directory
#   bd - deletes from $SELECTION_FILE
#   bs - selects and puts into $SELECTION_FILE
#   bp - pastes from $SELECTION_FILE into current direcotry
#   bm - moves from $SELECTION_FILE into current direcotry
#

SELECTION_FILE="$HOME/.bselection"

b() {
  truncate -s 0 "$SELECTION_FILE"
  while true; do
    selected=$( ( command ls -1ap | \
      grep -v '^./$'; printf "CREATE\nSELECT\nPASTE\nMOVE\nDELETE\n" ) | \
      sed -r 's/^(CREATE|SELECT|DELETE|PASTE|MOVE|\.\.\/)$/\x1b[33m&\x1b[0m/' | \
      fzf | \
      sed 's/\x1b\[[0-9;]*[mK]//g' )
    [ -z "$selected" ] && break
    case "$selected" in
      CREATE) bc ;;
      SELECT) bs ;;
      DELETE) bd ;;
      PASTE) bp ;;
      MOVE) bm ;;
      */) cd "$selected" ;;
      *) edit "$selected" ;;
    esac
  done
}

bc() {
  echo "Name of file or directory/ to create:"
  read new
  [ -z "$new" ] && return
  case "$new" in
    */) mkdir "$new" ;;
    *) touch "$new" ;;
  esac
}

bs() {
  local prev_selections=()
  [ -f "$SELECTION_FILE" ] && mapfile -t prev_selections < "$SELECTION_FILE"

  while true; do
    selected=$(
      ( command ls -1Ap; echo "DONE" ) | while IFS= read -r line; do
        if [ "$line" = "DONE" ]; then
          printf '\033[33m%s\033[0m\n' "$line"
        else
          match=false
          for stored_path in "${prev_selections[@]}"; do
            stored_base="$(basename "$stored_path")"
            [ -d "$stored_path" ] && [[ "$stored_base" != */ ]] && stored_base="$stored_base/"
            if [ "$line" = "$stored_base" ]; then
              match=true
              break
            fi
          done
          if $match; then
            printf '\033[36m%s\033[0m\n' "$line"
          else
            printf '%s\n' "$line"
          fi
        fi
      done | fzf
    )

    [ -z "$selected" ] && break

    if [ "$selected" = "DONE" ]; then
      break
    else
      selected_norm="${selected%/}"

      found=false
      for i in "${!prev_selections[@]}"; do
        stored_norm="$(basename "${prev_selections[i]}")"
        stored_norm="${stored_norm%/}"
        if [ "$selected_norm" = "$stored_norm" ]; then
          unset 'prev_selections[i]'
          found=true
          break
        fi
      done

      if ! $found; then
        [[ -d "$PWD/$selected" ]] && [[ "$selected" != */ ]] && selected="$selected/"
        prev_selections+=("$PWD/$selected")
      fi

      printf "%s\n" "${prev_selections[@]}" > "$SELECTION_FILE"
    fi
  done
}

bd() {
  local to_delete=()
  [ -f "$SELECTION_FILE" ] && mapfile -t to_delete < "$SELECTION_FILE"

  if [ ${#to_delete[@]} -eq 0 ]; then
    echo "Selection empty, select something first:"
    bs
    [ -f "$SELECTION_FILE" ] && mapfile -t to_delete < "$SELECTION_FILE"
    [ ${#to_delete[@]} -eq 0 ] && { echo "Selection empty, abort"; return 1; }
  fi

  echo "Selected to delete:"
  for f in "${to_delete[@]}"; do
    echo "  $f"
  done

  read -rp "Are you sure you want to delete these? [y/N]: " confirm
  case "$confirm" in
    [yY]|[yY][eE][sS])
      for f in "${to_delete[@]}"; do
        if [ -d "$f" ]; then
          rm -rf "$f"
        else
          rm -f "$f"
        fi
      done
      > "$SELECTION_FILE"
      echo "Deleted ${#to_delete[@]} items"
      ;;
    *)
      echo "Deletion aborted"
      ;;
  esac
}

bp() {
  local to_paste=()

  [ -f "$SELECTION_FILE" ] && mapfile -t to_paste < "$SELECTION_FILE"

  if [ ${#to_paste[@]} -eq 0 ]; then
    echo "Selection empty, select something first:"
    bs
    [ -f "$SELECTION_FILE" ] && mapfile -t to_paste < "$SELECTION_FILE"
    [ ${#to_paste[@]} -eq 0 ] && { echo "Selection empty, abort"; return 1; }
  else
    for src in "${to_paste[@]}"; do
      if [ ! -e "$src" ]; then
        echo "Source not found: $src" >&2
        continue
      fi

      base=$(basename "$src")

      if [ -e "$base" ]; then
        printf "Replace existing '%s'? [y/N]: " "$base"
        read -r answer
        case "$answer" in
          [Yy]*)
            echo "Replacing $base"
            cp -r --remove-destination "$src" . ;;
          *)
            echo "Skipping $base" ;;
        esac
      else
        echo "Copying $base"
        cp -r "$src" .
      fi
    done
  fi
}

bm() {
  local to_move=()

  [ -f "$SELECTION_FILE" ] && mapfile -t to_move < "$SELECTION_FILE"

  if [ ${#to_move[@]} -eq 0 ]; then
    echo "Selection empty, select something first:"
    bs
    [ -f "$SELECTION_FILE" ] && mapfile -t to_move < "$SELECTION_FILE"
    [ ${#to_move[@]} -eq 0 ] && { echo "Selection empty, abort"; return 1; }
  else
    for src in "${to_move[@]}"; do
      if [ ! -e "$src" ]; then
        echo "Source not found: $src" >&2
        continue
      fi

      base=$(basename "$src")

      if [ -e "$base" ]; then
        printf "Replace existing '%s'? [y/N]: " "$base"
        read -r answer
        case "$answer" in
          [Yy]*)
            echo "Replacing $base"
            [ -e "./$base" ] && rm -rf "$base"
            mv -f "$src" .
            > "$SELECTION_FILE" ;;
          *)
            echo "Skipping $base" ;;
        esac
      else
        echo "Moving $base"
        mv -n "$src" .
        > "$SELECTION_FILE"
      fi
    done
  fi
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

