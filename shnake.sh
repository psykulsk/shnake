#!/usr/bin/env bash


# check if script is executed with bash, version >= 4.0
if [[ -z $BASH_VERSION ]]; then
		echo 'Execute this script with bash, version >= 4.0'
		exit 1
fi

VERSION_ABOVE_OR_EQUAL_4_REGEX='^[^0-3]\..*\|^[0-9][0-9][0-9]*\..*'
echo $BASH_VERSION | grep $VERSION_ABOVE_OR_EQUAL_4_REGEX
if [[ $? -ne 0 ]]; then
	echo "Execute this script with bash, version >= 4.0. Your current version=$BASH_VERSION"
	exit 1
fi

# remove highlighted terminal cursor
tput civis
# reset to normal on exit
trap 'tput cnorm;' EXIT
# reset to normal on exit and clean screen on SIGINT (Ctrl-C)
trap 'tput cnorm; clear; exit;' SIGINT

# declare default options
declare -i cols=20
declare -i rows=12
X_TIME=0.1
Y_TIME=0.14
REFRESH_TIME=$X_TIME

# holds a screen matrix in an associative array
declare -A screen

# array with snakebody x coordinates
declare -a snakebod_x

# array with snakebody y coordinates
declare -a snakebod_y

# score
declare -i score=0

# initial snake velocity
declare -i vel_x=1
declare -i vel_y=0

# food position
declare -i food_x
declare -i food_y

# key input from user
key=""

# constants
declare -r SNAKE_ICON="X"
declare -r FOOD_ICON="O"
declare -r EMPTY=" "
declare -r ARROW_UP="A"
declare -r ARROW_DOWN="B"
declare -r ARROW_RIGHT="C"
declare -r ARROW_LEFT="D"
declare -r HORIZONTAL_BAR="-"
declare -r VERTICAL_BAR="|"
declare -r CORNER_ICON="+"

parse_args ()
{
	local OPTIND opt
	while getopts ":c:r:s:h" opt; do
		case ${opt} in
			c )
			cols=$OPTARG
			;;
			r )
			rows=$OPTARG
			;;
			s )
			set_speed "$OPTARG"
			;;
			h )
			usage
			exit 0
			;;
			\? )
			usage
			exit 1
			;;
		esac
	done
}

set_speed () 
{
	local speed_level=$1

	case ${speed_level} in
		1)
		X_TIME=0.8
		Y_TIME=1
		;;
		2)
		X_TIME=0.6
		Y_TIME=0.8
		;;
		3)
		X_TIME=0.4
		Y_TIME=0.6
		;;
		4)
		X_TIME=0.2
		Y_TIME=0.4
		;;
		5)
		X_TIME=0.1
		Y_TIME=0.2
		;;
		6)
		X_TIME=0.08
		Y_TIME=0.16
		;;
		7)
		X_TIME=0.06
		Y_TIME=0.12
		;;
		8)
		X_TIME=0.04
		Y_TIME=0.08
		;;
		9)
		X_TIME=0.02
		Y_TIME=0.04
		;;
		10)
		X_TIME=0.01
		Y_TIME=0.02
		;;
		*)
		usage
		exit 1
		;;
	esac
	REFRESH_TIME=$X_TIME
}

usage ()
{
    echo "usage: $0 [-c cols ] [-r rows] [-s speed]"
    echo "  -h display help"
    echo "  -c cols specify game area cols. Make sure it's not higher then the actual terminal's width. "
    echo "  -r rows specify game area rows. Make sure it's not higher then the actual terminal's height."
    echo "  -s speed specify snake speed. Value from 1-10."
}

clear_game_area_screen ()
{
	clear
	for ((i=1;i<rows;i++)); do
		for ((j=1;j<cols;j++)); do
			screen[$i,$j]=$EMPTY
		done
	done
	draw_game_area_boundaries
}

draw_game_area_boundaries()
{
	for i in 0 $rows; do
		for ((j=0;j<cols;j++)); do
			screen[$i,$j]=$HORIZONTAL_BAR
		done
	done
	for j in 0 $cols; do
		for ((i=0;i<rows+1;i++)); do
			screen[$i,$j]=$VERTICAL_BAR
		done
	done
	screen[0,0]=$CORNER_ICON
	screen[0,$cols]=$CORNER_ICON
	screen[$rows,$cols]=$CORNER_ICON
	screen[$rows,0]=$CORNER_ICON
}

print_screen ()
{
	for ((i=0;i<rows+1;i++)); do
		for ((j=0;j<cols+1;j++)); do
			printf "${screen[$i,$j]}"
		done
		printf "\n"
	done
}

handle_input ()
{
	if [[ "$1" = "$ARROW_UP" ]]; then
		if (( vel_y != 1 )); then
			vel_x=0
			vel_y=-1
			REFRESH_TIME=$Y_TIME
		fi
	elif [[ "$1" = "$ARROW_DOWN" ]]; then
		if (( vel_y != -1 )); then
			vel_x=0
			vel_y=1
			REFRESH_TIME=$Y_TIME
		fi
	elif [[ "$1" = "$ARROW_RIGHT" ]]; then
		if (( vel_x != -1 )); then
			vel_x=1
			vel_y=0
			REFRESH_TIME=$X_TIME
		fi
	elif [[ "$1" = "$ARROW_LEFT" ]]; then
		if (( vel_x != 1 )); then
			vel_x=-1
			vel_y=0
			REFRESH_TIME=$X_TIME
		fi
	else
		:
	fi
}

# Sets new food position randomly, it has to be an empty field
set_food ()
{
	while :; do
		food_x=$(( 1+$RANDOM%(cols-1) ))
		food_y=$(( 1+$RANDOM%(rows-1) ))
		screen_val=${screen[$food_y,$food_x]}
		if [[ $screen_val == $EMPTY ]]; then
			screen[$food_y,$food_x]=$FOOD_ICON
			set_pixel "$food_y" "$food_x" "$FOOD_ICON"
			return
		fi
	done
}

calc_new_snake_head_x () {
	local cur_head_x=$1
	local v_x=$2
	new_head_x=$(( cur_head_x+v_x ))
	if (( new_head_x == 0 )); then
		new_head_x=$(( cols-1 ))
	elif (( new_head_x == cols )); then
		new_head_x=1
	fi
}

calc_new_snake_head_y () {
	local cur_head_y=$1
	local v_y=$2
	new_head_y=$(( cur_head_y+v_y ))
	if (( new_head_y == 0 )); then
		new_head_y=$(( rows-1 ))
	elif (( new_head_y == rows )); then
		new_head_y=1
	fi
}

check_win_cond () {
	local max_snake_length=$(( (rows-1)*(cols-1) ))
	if [[ ${#snakebod_x[@]} -eq $max_snake_length ]]; then
		set_cursor_below_game
		echo You won! Congratulations!
		exit 0
	fi
}

game ()
{
	clear_snake
	local head_x=${snakebod_x[0]}
	local head_y=${snakebod_y[0]}
	declare -i new_head_x
	declare -i new_head_y
	calc_new_snake_head_x $head_x $vel_x
	calc_new_snake_head_y $head_y $vel_y
	local snake_length=${#snakebod_x[@]}

	# check if new head positions is not inside snake
	for ((i=0;i<snake_length-1;i++));
	do
		if [[ ${snakebod_y[i]} -eq $new_head_y ]] && [[ ${snakebod_x[i]} -eq $new_head_x ]]; then
			set_cursor_below_game
			echo Snake ate itself. You lose!
   			echo Your score was: $score
			exit 0
		fi
	done

	# if head is were food is, do not remove the last element of snake body and set new food position
	if (( new_head_x == food_x )) && (( new_head_y == food_y )); then
		snakebod_x=($new_head_x ${snakebod_x[@]:0:${#snakebod_x[@]}})
		snakebod_y=($new_head_y ${snakebod_y[@]:0:${#snakebod_y[@]}})
		draw_snake
		check_win_cond
		set_food
          	((score++))
	else
		snakebod_x=($new_head_x ${snakebod_x[@]:0:${#snakebod_x[@]}-1})
		snakebod_y=($new_head_y ${snakebod_y[@]:0:${#snakebod_y[@]}-1})
		draw_snake
	fi
}

clear_snake ()
{
	local snake_length=${#snakebod_x[@]}
	for ((i=0;i<snake_length;i++));
	do
		screen[${snakebod_y[i]},${snakebod_x[i]}]=$EMPTY
	done
	set_pixel "${snakebod_y[snake_length-1]}" "${snakebod_x[snake_length-1]}" "$EMPTY"
}

draw_snake ()
{
	local snake_length=${#snakebod_x[@]}
	for ((i=0;i<snake_length;i++));
	do
		screen[${snakebod_y[i]},${snakebod_x[i]}]=$SNAKE_ICON	
	done
	set_pixel "${snakebod_y[0]}" "${snakebod_x[0]}" "$SNAKE_ICON"
}

set_pixel ()
{
	tput cup "$1" "$2"
	printf "%s" "$3"
}

set_cursor_below_game ()
{
	tput cup $(($rows+1)) 0
}

# execute game loop, then sleep for REFRESH_TIME in a subshell and send SIGALRM to the current process
# thanks to the trap below it will trigger the game loop again
tick() {
	tput cup 0 0
	handle_input "$key"
	game
	( sleep $REFRESH_TIME; kill -s ALRM $$ &> /dev/null )&
}
trap tick ALRM

parse_args "$@"
# initialize game area
snakebod_x=( $((cols/2)) )
snakebod_y=( $((rows/2)) )
clear_game_area_screen
print_screen
set_food
# start game
tick
# poll for user input in loop
for (( ; ; ))
do
	read -rsn 1 key
done
