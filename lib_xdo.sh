#!/bin/bash
# xdotool utilities functions

# eval $(xdo_getwg 'window name')
# sets WINDOW X Y WIDTH HEIGHT SCREEN
xdo_getwg(){
	while	! xdotool search --name "$@"
	do	sleep 1
	done
	xdotool search --name "$@" getwindowgeometry --shell
}

# xdo_clickw 'window name' 'target' [corner_offset_px]
# target: corner ('00' for top left|'X0'|'0Y'|'XY') or explicit coord ("$c_x,$c_y")
xdo_clickw(){
	WNAME="$1"
	TARGET="$2"
	OFFSET=${3:-20}
	eval $(xdo_getwg "$WNAME")
	case "$TARGET" in
	'00')	c_x=$OFFSET
		c_y=$OFFSET
		;;
	'X0')	c_x=$((WIDTH - OFFSET))
		c_y=$OFFSET
		;;
	'0Y')	c_x=$OFFSET
		c_y=$((HEIGHT - OFFSET))
		;;
	'XY')	c_x=$((WIDTH - OFFSET))
		c_y=$((HEIGHT - OFFSET))
		;;
	*)	c_x=${TARGET%,*}
		c_y=${TARGET#*,}
		;;
	esac
	xdotool search --name "$WNAME" windowactivate --sync %@ mousemove --sync --window %@ "$c_x" "$c_y" click 1
}

# xdo_type 'window name' 'input'
xdo_type(){
	WNAME="$1"
	shift
	INPUT="$*"
	xdotool search --name "$WNAME" windowactivate type "$INPUT"
}
