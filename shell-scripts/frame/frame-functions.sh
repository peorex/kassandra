

# Functions library
# Author: Georgi Kovachev
# Version=1.0.4

# belongs to 'frame' script
# 
# 
# 

feedback ()
{
	case "${1}-$es" in
		--on-load-0)
			:
		;;
		--on-load-*)
			echo ''
			echo "$ME: ERRORS FOUND"
			usage
		;;
		--on-exit-0)
			echo "$ME: Success"
		;;
		--on-exit-*)
			echo ''
			echo "$ME: ERRORS FOUND"
		;;
		--on-xxxx-0)
			if [ "$cmd" = 'cmd1'  -o  "$cmd" = 'cmd2'  -o  "$cmd" = 'cmd3' ]; then
				echo "$ME: Summary:"
				echo "    Command:      $cmd"
				echo "    Source:       $src		$dev"
				echo "    Destination:  $dst		$dev"
				echo "    Assume Yes:   $opt_yes"
				fb_prompt -t "$assume_yes"
				echo ''
			fi
		;;
		--on-xxxx-*)
			:
		;;
	esac
} >&2

usage ()
{
	echo "
Usage:
$ME  cmd1  -|file|device|dir  -|bak-file  [--opt1|--opt2]  # cmd1 purpose
$ME  cmd2  -|file             -|device                     # cmd2 purpose
$ME  cmd3  dir                dir                          # cmd3 purpose
$ME  cmd4  device|dir                                      # cmd4 purpose
Options:
    -a           - sample option
    -f argument  - sample option
    -n           - sample option
    -v           - sample option
    --help       - display this help and exit
    --version    - output version information and exit
	" >&2
	[ $es -eq 0 ] && exit "${1:-0}"	|| exit $es
}

init ()
{
# Get command line parameters
	cmd=$1					# command
	case "$#" in
		0)
			cmd='cmd1'		# mangle command
		;;
		*)	:	;;	# for tests
		1|2|3|4)
			src=$2			# source
			dst=$3			# destination
			dev=$4			# device
		;;
		*)	es=2				;;
	esac
	[ $es -eq 0 ]	|| return $es

	opts=${a:+'-a'}

# Check if the configuration satisfy the requirements
	must_be_installed -s		# for tests

	dst=$(readlnk -- "$dst")			|| ! echo "Cannot resolve $dst"	|| es=26

#	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving

	return 0			# for tests

	case "$cmd" in
		cmd2 | cmd3)
			case "$cmd" in
				cmd1 | cmd2)
					[ -n "$src" ]	|| ! echo "Source is empty"	|| es=11
					[ -n "$dst" ]	|| return 12
				;;
			esac

			[ -n "$dev" ]			|| ! echo "Device is empty"	|| es=13
			must_be_installed tar
		;;
	esac
	return $es
}



