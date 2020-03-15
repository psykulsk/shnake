#/usr/bin/env sh


trap 'tput cnorm; echo Exitting $0' EXIT
tput civis

cols=20
rows=12
X_TIME=0.1
Y_TIME=0.14
REFRESH_TIME=$X_TIME
declare -A screen

snake_icon="X"
food_icon="O"
empty=" "

arrowup="A"
arrowdown="B"
arrowrt="C"
arrowleft="D"

clear_screen ()
{
	for ((i=1;i<rows;i++)); do
		for ((j=1;j<cols;j++)); do
			screen[$i,$j]=$empty
		done
	done
	draw_game_area
}

draw_game_area()
{
	for i in 0 $rows; do
		for ((j=0;j<cols;j++)); do
			screen[$i,$j]="-"
		done
	done
	for j in 0 $cols; do
		for ((i=0;i<rows+1;i++)); do
			screen[$i,$j]="|"
		done
	done
	screen[0,0]='+'
	screen[0,$cols]='+'
	screen[$rows,$cols]='+'
	screen[0,0]='+'
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

vel_x=1
vel_y=0

head_x=10
head_y=10

handle_input ()
{
	if [[ "$1" = "$arrowup" ]]; then
		if (( vel_y != 1 )); then
			vel_x=0
			vel_y=-1
			REFRESH_TIME=$Y_TIME
		fi
	elif [[ "$1" = "$arrowdown" ]]; then
		if (( vel_y != -1 )); then
			vel_x=0
			vel_y=1
			REFRESH_TIME=$Y_TIME
		fi
	elif [[ "$1" = "$arrowrt" ]]; then
		if (( vel_x != -1 )); then
			vel_x=1
			vel_y=0
			REFRESH_TIME=$X_TIME
		fi
	elif [[ "$1" = "$arrowleft" ]]; then
		if (( vel_x != 1 )); then
			vel_x=-1
			vel_y=0
			REFRESH_TIME=$X_TIME
		fi
	else
		:
	fi
}


snakebod_x=( $((cols/2)) )
snakebod_y=( $((rows/2)) )

declare -i food_x
declare -i food_y

set_food ()
{
	while :; do
		food_x=$(( 1+$RANDOM%(cols-1) ))
		food_y=$(( 1+$RANDOM%(rows-1) ))
		screen_val=${screen[$food_y,$food_x]}
		if [[ $screen_val == $empty ]]; then
			screen[$food_y,$food_x]=$food_icon
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
		echo You won! Congratulations!
		exit 0
	fi
}

game ()
{
	check_win_cond
	clear_snake
	head_x=${snakebod_x[0]}
	head_y=${snakebod_y[0]}
	declare -i new_head_x
	declare -i new_head_y
	calc_new_snake_head_x $head_x $vel_x
	calc_new_snake_head_y $head_y $vel_y
	local snake_length=${#snakebod_x[@]}
	for ((i=0;i<snake_length;i++));
	do
		if [[ ${snakebod_y[i]} -eq $new_head_y ]] && [[ ${snakebod_x[i]} -eq $new_head_x ]]; then
			echo Snake ate itself. You lose!
			exit 0
		fi
	done
	if (( new_head_x == food_x )) && (( new_head_y == food_y )); then
		snakebod_x=($new_head_x ${snakebod_x[@]:0:${#snakebod_x[@]}})
		snakebod_y=($new_head_y ${snakebod_y[@]:0:${#snakebod_y[@]}})
		draw_snake
		set_food
	else
		snakebod_x=($new_head_x ${snakebod_x[@]:0:${#snakebod_x[@]}-1})
		snakebod_y=($new_head_y ${snakebod_y[@]:0:${#snakebod_y[@]}-1})
	fi
	draw_snake
}

clear_snake ()
{
	local snake_length=${#snakebod_x[@]}
	for ((i=0;i<snake_length;i++));
	do
		screen[${snakebod_y[i]},${snakebod_x[i]}]=$empty
	done
}

draw_snake ()
{
	local snake_length=${#snakebod_x[@]}
	for ((i=0;i<snake_length;i++));
	do
		screen[${snakebod_y[i]},${snakebod_x[i]}]=$snake_icon	
	done
}


tick() {
	clear
	handle_input $key
	game
	print_screen
	( sleep $REFRESH_TIME; kill -s ALRM $$ )&
}

trap tick ALRM

key=""
clear_screen
set_food
tick
for (( ; ; ))
do
	read -rsn 1 key
done