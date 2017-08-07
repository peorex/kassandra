

# Functions library
# Author: Georgi Kovachev
# Version=1.0.6

# belongs to 'secure-device.sudo' script
# 
# 
# 

# Checks input parameters
# Input:  $@ - command line
# Output: $action is set to appropriate value
# Exit status: 0 if success, 1 if error
get_cmd_line_parameters ()
{
	local es=0

	#	echo "Usage: $0 create [file|mountpoint|name]" >&2
	#	echo "Usage: $0 mount  [file|mountpoint|name]" >&2
	#	echo "Usage: $0 umount [file|mountpoint|name]" >&2
	#	echo "Usage: $0 [use   [file|mountpoint|name]]" >&2

	[ "$1" ] && action="$1"		# create	mount	umount	use
	[ "$2" ] && mount_file="$2"	# file or directory

	case "$action" in
		create|mount|umount|use)
			if [ $# -gt 2 ]; then
				echo "$ME: Error: Too many parameters" >&2; es=1
			fi
		;;
		--version|--help)	:	;;
		*)
			if [ "$action" ];then
				echo "$ME: Error: Illegal command: $action" >&2
				es=1
			fi
		;;
	esac

	return $es
}

# Read settings from config file
# Input:  None
# Output: None
# Exit status: 0 if success, greater than 0 if error
get_configuration_settings ()
{
	local es=0 keep_IFS=$IFS config_file_entry='' i='' mnt_f="$mount_file"

#	IFS=$'\n'			# set input field separator to new line
	# get configuration settings
	config_file_entry=$(remove_comments_from_file "$config_file" | tac) || es=1
	if [ $es -ne 0 ]; then
		echo -n "$ME: Error: Cannot read configuration" >&2
		echo " file ${config_file}" >&2
		return $es
	fi

	mount_file=$(get_mounts '' "$mnt_f" "$config_file")
	mount_point=$(get_mounts "$mnt_f" '' "$config_file")

#	for i in $config_file_entry; do
#	echo "$config_file_entry" | \
	while read i; do
		eval set -- "$i" 2>/dev/null || es=2
		if [ $es -ne 0 ]; then
			echo -n "$ME: Error: Syntax error in configuration" >&2
			echo " file ${config_file} line:" >&2
			echo "$ME: $i" >&2
		fi

		if [ -z "$mnt_f" ]  ||  [ "$mnt_f" = "$6" ]  ||  \
			[ "$1" = "$mount_file"  -a  "$2" = "$mount_point" ]; then
			mount_file="$1"
			mount_point="$2"
			fs_type="$3"
			fs_opts="$4"
			size="$5"
			name="$6"
		fi
	done <<< "$config_file_entry"
	[ "$fs_opts" = "0" ] && fs_opts=''

	IFS=$keep_IFS

	mount_file=$(readlnk "$mount_file")	|| return 1
	mount_point=$(readlnk "$mount_point")	|| return 1

	return $es
}

# Checks if the configuration satisfy the requirements
# Input:  None
# Output: None
# Exit status: 0 if success, greater than 0 if error
config_check ()
{
	local tmp='' fs='' es=0

	if [ -z "$mount_file"  -o  -z "$mount_point"  -o  \
		-z "$fs_type"  -o  -z "$size" ]; then
	echo "$ME: Error: Destination $mount_file is not found as Security Device." >&2
				es=1
	fi

	fs=$(basename "$mount_file")

	case "$action" in
		create)
			if [ -e "$mount_file" ]; then
	echo "$ME: Error: Destination $mount_file exists. Will NOT overwrite it!" >&2
				es=1
			fi

			if [ "${size: -1:1}" = 'K'  -o  "${size: -1:1}" = 'M' ]; then
				tmp=$(str2int "${size%?}") || es=2
				if [ $es -ne 2 ]; then
					if [ $tmp -lt 0 ]; then
	echo "$ME: Error: Size is less than zero: $size" >&2
						es=1
					fi
				else
	echo "$ME: Error: Invalid 'size' format: ${size}." >&2
	echo "$ME: Error: Use integer values only that must" >&2
	echo "$ME: Error: end with 'K' for KB or 'M' for MB" >&2
					es=1
				fi
			else
	echo "$ME: Error: Invalid 'size' format: $size" >&2
	echo "$ME: Error: Must end with 'K' for KB or 'M' for MB" >&2
				es=1
			fi
		;;

		mount)
			[ ! -f "$mount_file" ] && es=1 && \
	echo "$ME: Error: File $mount_file does not exist." >&2
			[ ! -d "$mount_point" ] && es=1 && \
	echo "$ME: Error: Directory $mount_point does not exist." >&2

			tmp=$(get_mounts "/dev/mapper/$fs" '' /etc/mtab)
			[ $es -eq 0 ] && [ "$tmp" ] && \
	echo "$ME: Error: File $mount_file already mounted at $tmp" >&2 && es=1
		;;

		umount)
			[ -f "$mount_file" ] || \
	echo "$ME: WARNING: File $mount_file does not exist." >&2
		;;

		use)
			[ ! -f "$mount_file" ] && es=1 && \
	echo "$ME: Error: File $mount_file does not exist." >&2
			[ ! -d "$mount_point" ] && es=1 && \
	echo "$ME: Error: Directory $mount_point does not exist." >&2
		;;
	esac

	return $es
}

err_decoder ()
{
	[ $es -eq 0  -o  $es -gt 64 ] && return

	echo -e "\n$ME: Errors returned by  ${ME}.sudo" >&2
	echo "$ME: Exit status: $es" >&2

	case $es in
		1)	echo "$ME: General error."					;;
		16)	echo "$ME: Insufficient size ${size}."
			echo "$ME: Use at least 2080K for ext3 and 128K for others."	;;
		18)	echo "$ME: File $mount_file is not owned by you."		;;
		19)	echo "$ME: Block device /dev/mapper/$fs is not owned by you."	;;
		24)	echo "$ME: Cannot create file system."				;;
		31)	echo "$ME: Incorrect password or corrupted file system."	;;
		52)	echo "$ME: Cannot get loop device."				;;
		61)	echo "$ME: Cannot unmount /dev/mapper/$fs"			;;
		*)	echo "$ME: No message is written for this exit status."		;;
	esac
}

feedback ()
{
	case "${1}-$es" in
		--on-load-0)
			if [ "$cmd" = 'create'  -o  "$cmd" = 'mount' ]; then
				echo "$ME: Summary:"
				echo "    Command:             $cmd"
				echo "    File:                $mount_file"
				echo "    Mount point:         $mount_point"
				if [ "$cmd" = 'create' ]; then
					echo "    File system type:    $fs_type"
					echo "    File system options: $fs_opts"
					echo "    Size:                $size"
				fi
				echo "    Device name:         $name"
				echo ''
				fb_prompt -t
				echo ''
			fi
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
			err_decoder
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
$ME  create [file|mountpoint|name]   # create security filesystem
$ME  mount  [file|mountpoint|name]   # mount security filesystem
$ME  umount [file|mountpoint|name]   # unmount security filesystem
$ME  [use   [file|mountpoint|name]]  # mount, start application, unmount afrer use
Options:
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
		*)	:	;;	# for tests
		0)
			cmd='cmd1'		# mangle command
		;;
		1|2|3|4)
			src=$2			# source
			dst=$3			# destination
			dev=$4			# device
		;;
		*)	es=2				;;
	esac
	[ $es -eq 0 ]	|| return $es

#	opts=${a:+'-a'}

# Check if the configuration satisfy the requirements
	must_be_installed sudo

	dst=$(readlnk -- "$dst")			|| ! echo "Cannot resolve $dst"	|| es=26

#	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving

	echo ''
	get_cmd_line_parameters "$@" || es=2
	get_configuration_settings   || es=3
	config_check || es=$?	# can the configuration satisfy the requirements?

	cmd=$action
	return $es

	case "$cmd" in
		cmd2 | cmd3)
			case "$cmd" in
				cmd1 | cmd2)
					[ -n "$src" ]	|| ! echo "Source is empty"	|| es=11
					[ -n "$dst" ]	|| return 12
				;;
			esac

			[ -n "$dev" ]			|| ! echo "Device is empty"	|| es=13
			must_be_installed -s tar
		;;
	esac
	return $es
}

