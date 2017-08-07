

# Functions library
# Author: Georgi Kovachev
# Version=1.0.0

# belongs to 'arch' script
# 
# 
# 

get_configuration_settings ()
{
	local config_file_entry i

	[ -e "$config_file" ]	|| here_config_file			|| return 1
	config_file_entry=$(remove_comments_from_file "$config_file")	|| return 2

	while read i ; do
		i=$(name_eq_value "$i")			# trim needless white space
		case "$i" in
			db_directory=*)	db_dir=${i#db_directory=}	;;
			verbose=*)	verbose=${i#verbose=}		;;
		esac
	done <<- EOCFE
		$config_file_entry
	EOCFE
}

here_config_file ()
{
	echo "
# Configuration file $config_file
# for $SELFNAME utility
# This file is created automatically if one does not exist.
# If it exists it is not modified by the program in any way.
#
# Comments begin with '#' mark.
# Blank lines are ignored.


# Format is option=value

# Database directory must be set.
db_directory	= $db_dir

verbose		= yes			# verbose, overriden by command line option
# verbose	= no			# no verbose, overriden by command line option


" >"$config_file"
}

verify_label ()
{
	local es

	es=0
	if [ -e "$db_dir/$label"  -a  ! -f "$db_dir/$label" ]   || \
		[ -h "$db_dir/$label" ]; then
		! echo "$ME: $db_dir/$label  is not a regular file"	|| es=1
	fi
	if [ ! -r "$db_dir/$label"  -o  ! -w "$db_dir/$label" ] && \
		[ -e "$db_dir/$label" ]; then
		! echo "$ME: Permission denied to  $db_dir/$label"	|| es=2
	fi
	return $es
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
$ME  [-nv] add               label dir  # add directory to archive catalog
$ME  [-n]  del|delete|remove label      # remove directory from archive catalog
$ME  [-I]  [find]            string     # find substring
Options:
    -I         - do not ignore case distinctions
    -l label   - find from label
    -n         - dry run
    -v         - verbose
    --help     - display this help and exit
    --version  - output version information and exit
	" >&2
	[ $es -eq 0 ] && exit "${1:-0}"	|| exit $es
}

init ()
{
# Get command line parameters
	cmd=$1					# command
	case "$#" in
		0|1|2|3)
			label=$2		# volume label
			directory=$3		# destination directory
		;;
		*)	es=2				;;
	esac
	[ $es -eq 0 ]	|| return $es

	get_configuration_settings

	[ "$verbose" = 'yes' ]	&& verb='v'
	[ -n "$V" ]		&& verb=''
	[ -n "$v" ]		&& verb='v'

# Check if the configuration satisfy the requirements
	must_be_installed

	directory=$(readlnk -- "$directory")				|| \
		! echo "$ME: Cannot resolve $directory"				|| es=26
	db_dir=$(readlnk -- "$db_dir")					|| \
		! echo "$ME: Cannot resolve  $db_dir"				|| es=26

#	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving

	case "$cmd" in
		add)
			[ -n "$label" ]	|| ! echo "$ME: Label is empty"		|| es=11

			[ -d "$db_dir"  -o  ! -e "$db_dir" ]		|| \
			! echo "$ME: Permission denied to  $db_dir"		|| es=12

			if [ -d "$db_dir" ]; then
				[ -r "$db_dir"  -a  -w "$db_dir" ]	|| \
				! echo "$ME: Permission denied to  $db_dir"	|| es=13
			fi
		;;
		del | delete | remove)
			cmd='remove'		# mangle command

			[ -n "$label" ]	|| ! echo "$ME: Label is empty"		|| es=14

			if [ -d "$db_dir" ]; then
				[ -r "$db_dir"  -a  -w "$db_dir" ]	|| \
				! echo "$ME: Permission denied to  $db_dir"	|| es=15
			else
				! echo "$ME: Directory  $db_dir does not exist"	|| es=16
			fi
		;;
		*)
			cmd='find'		# mangle command

			if [ -d "$db_dir" ]; then
				[ -r "$db_dir" ]			|| \
				! echo "$ME: Permission denied to  $db_dir"	|| es=17
			else
				! echo "$ME: Directory  $db_dir does not exist"	|| es=18
			fi
		;;
	esac

	return $es
}



