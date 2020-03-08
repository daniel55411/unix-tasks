#!/bin/bash

# System functions
init() {
  init_vars

  if [[ $IS_ADMIN -eq 0 ]]
  then
    mkfifo "$FIFO"

    if mkfifo "$FIFO"
    then
      echo "Error while creating FIFO..." >&2
      exit
    fi
  fi
}

init_vars() {
  FIFO=tic-tac-toe-fifo
  if [[ ! -p $FIFO ]]
  then
    IS_ADMIN=0
  else
    IS_ADMIN=1
  fi

  if [[ $IS_ADMIN -eq 0 ]]
  then
    SYMBOL='X'
    ENEMY_SYMBOL='O'
  else
    SYMBOL='O'
    ENEMY_SYMBOL='X'
  fi
}

cleanup() {
  rm -f $FIFO
}


# Game init functions
MAP=(" " " " " " " " " " " " " " " " " " " ")

draw_map() {
  clear
  echo " ${MAP[0]} | ${MAP[1]} | ${MAP[2]} "
  echo "---+---+---"
  echo " ${MAP[3]} | ${MAP[4]} | ${MAP[5]} "
  echo "---+---+---"
  echo " ${MAP[6]} | ${MAP[7]} | ${MAP[8]} "
}

set_map() {
  INDEX=$((X * 3 + Y))
  MAP[$INDEX]=$1
}

autoread() {
  local line

  if [[ -z $1 ]]
  then
    read -r line
  else
    read -r line<"$1"
  fi

  if [[ $line =~ ^([1-3])\ ([1-3])$ ]]
  then
    X="${BASH_REMATCH[1]}"
    Y="${BASH_REMATCH[2]}"
  else
    return 0
  fi

  return 1
}

autowrite() {
  if [[ -z $2 ]]
  then
    echo "$1"
  else
    echo "$1" >"$2"
  fi
}

our_turn_read() {
  read_XY
  echo "$((X+1)) $((Y+1))" > $FIFO
  set_map $SYMBOL
}

read_XY() {
  if [[ -n $1 ]]
  then
    WHERE=$1
  else
    unset WHERE
  fi

  while true
  do
    if [[ -z $1 ]]
    then
      echo -n "Your turn: "
    fi

    if autoread "$1"
    then
      echo "Wrong input data. Try again..."
      continue
    fi

    X=$((X-1))
    Y=$((Y-1))
    INDEX=$((X * 3 + Y))

    if [[ ${MAP[INDEX]} != " " ]]
    then
      autowrite "Try another position..." "$WHERE"
    else
      break
    fi
  done
}

game_loop() {
  if [[ $IS_ADMIN -eq 0 ]]
  then
    draw_map
    our_turn_read
  fi

  while true
  do
    draw_map
    echo "Wait your opponent..."
    read_XY $FIFO
    set_map $ENEMY_SYMBOL
    check_game_over $ENEMY_SYMBOL
    draw_map
    our_turn_read
    check_game_over $SYMBOL
  done

}

# Game logic functions
game_over() {
  draw_map

  if [[ $1 -eq 1 ]]
  then
    echo "Draw!"
    cleanup
    exit 0
  fi

  if [[ $2 == "$SYMBOL" ]]
  then
    echo "You win!"
  else
    echo "You lose!"
  fi

  cleanup
  exit 0
}

check_game_over() {
  local i
  EMPTY_CELL=0

  for i in {0..2}
  do
    if check_line "$1" "$i" "row"
    then
      game_over 0 "$1"
    fi

    if check_line "$1" "$i" "column"
    then
      game_over 0 "$1"
    fi
  done

  if check_diags "$1"
  then
    game_over 0 "$1"
  fi

  if [[ $EMPTY_CELL -eq 0 ]]
  then
    game_over 1
  fi
}

check_line() {
  local j
  local expected_symbol=$1
  local line=$2
  local win=0

  for j in {0..2}
  do
    if [[ $3 == "row" ]]
    then
      index=$((line * 3 + j))
    else
      index=$((j * 3 + line))
    fi

    if [[ ${MAP[$index]} != "$expected_symbol" ]]
    then
      if [[ ${MAP[$index]} == " " ]]
      then
        EMPTY_CELL=$((EMPTY_CELL + 1))
      fi
      win=1
    fi
  done

  return $win
}

check_diags() {
  if [[ ${MAP[4]} != "$1" ]]
  then
    return 1
  fi

  if [[ ${MAP[0]} == "$1" ]] && [[ ${MAP[8]} == "$1" ]]
  then
    return 0
  fi

  if [[ ${MAP[2]} == "$1" ]] && [[ ${MAP[6]} == "$1" ]]
  then
    return 0
  fi

  return 1
}

clear
init
game_loop
