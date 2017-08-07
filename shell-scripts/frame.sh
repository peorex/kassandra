#!/bin/bash -e

# The purpose of program
# Author: Georgi Kovachev
  Version=1.0.4

# Short description
# 
# 
# 

PATH=/sbin:/usr/sbin:/bin:/usr/bin		# or PATH=/bin:/usr/bin
sync
ME=$(basename       -- "$0")			# program name as invoked
SELF=$(readlink -ve -- "$0")			# /absolute/path/program
SELFDIR=$(dirname   "$SELF")			# /absolute/path
SELFNAME=$(basename "$SELF")			# program (true name)


# configuration start -------------------------
config_file=~/.kassandra/${SELFNAME}.conf	# important! /home/user/.pkg/progname.conf
config_file="${SELF}.conf"			# depends on program location and name
config_param='value'				# configuration parameter







options='a:f:f:nv'				# global options
log_opts='a=$a f="$f" n=$n v=$v'		# write options to log file
LOGFILE='/var/log/kassandra/kassandra.log'	# general log file for kassandra utilities
LOGPREFIX='cmd=$cmd es=$es'			# log message prefix
LOGSUFFIX='USER=$USER SUDO_USER=$SUDO_USER'	# log message suffix
VERBOSE=''					# 0 - never, 2 - disable, 7 - enable, 9 - max
EXECUTE=''					# 0 - never, 2 - disable, 7 - enable, 9 - max
# configuration end ===========================

# global variables start ----------------------
es=0						# exit status
cmd=$1						# command

src=''						# source
dst=''						# destination
dev=''						# device
opts=''						# options
assume_yes=''					# assume 'yes' to all questions








# global variables end ========================


# load general functions
f=${SELFDIR}/lib/functions.sh
[ -f "$f"  -a  -r "$f" ] && . "$f"	|| \
{ echo "$ME: FATAL ERROR: $f cannot be loaded. Aborting." >&2 ; exit 1 ; }

# load required files
# load_libs  lib/encryption-functions.sh
# load_libs  ${SELF}-functions.sh  ${SELF}-do-functions.sh

# embeded functions go here

do_cmd1 ()
{
	echo "Ffunction do_$cmd called"
}

do_cmd2 ()
{
	echo "Ffunction do_$cmd called"
}

do_cmd3 ()
{
	echo "Ffunction do_$cmd called"
}

do_cmd4 ()
{
	echo "Ffunction do_$cmd called"
}

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

# load_libs -f  ${SELF}-dev-functions.sh -- "$@"	# for development purposes

log Load: \$@="$@"				# log load parameters

case "$1" in
	--version)		version	;;	# exits with status 0
	--help | --usage)	usage	;;	# exits with status 0
esac

# must_be_root					# root permissions required - exit if not granted
getoptions "$options" "$@"	&& shift $((OPTIND-1))	|| es=2
init "$@"			|| es=$?

log Init: "$(eval echo "$log_opts")" \$@="$@"	# log decoded parameters

feedback --on-load		|| es=$?
[ $es -eq 0 ]			|| exit $es

# move up to action: do what is needed
sync
case "$cmd" in
	cmd1 | cmd2 | cmd3 | cmd4)
		do_$cmd "$@"
	;;
	*)
		usage 1
	;;
esac
feedback --on-exit

log Exit:					# log exit status

sync
exit $es

