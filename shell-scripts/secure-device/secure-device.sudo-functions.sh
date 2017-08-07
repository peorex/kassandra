

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

	# Usage: $0 create|mount|umount file mountpoint size fstype fsoptions

	action="$1"

	case "$action" in
		create|mount|umount)
			[ $# -ne 6 ] && es=1
			mount_file="$2"
			mount_point="$3"
			fs_type="$4"
			fs_opts="$5"
			size="$6"
		;;
		--version|--help)	:	;;
		*)
			es=1
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
	local config_file_entry='' i='' keep_IFS=$IFS es=0

	IFS=$keep_IFS
	return $es
}


# Checks if the configuration satisfy the requirements
# Input:  None
# Output: None
# Exit status: 0 if success, greater than 0 if error
config_check ()
{
	local sz='' offs='' tmp=''

	[ $es -eq 0 ] || return 0	# do not change the global exit status
	must_be_root		# exit if not root
	[ "$action" = '--version'  -o  "$action" = '--help' ] && return 0

	[	"$mount_file"	-a	"$mount_point"	-a  \
		"$fs_type"	-a	"$size" ] || return 11

	fs=$(basename "$mount_file")
	[ "$fs_type" = 'msdos'  -o  "$fs_type" = 'vfat' ] && chown_dis=1
	[ "$chown_dis" ] && mount_opts="-o uid=$SUDO_USER,gid=$SUDO_USER" || \
		mount_opts='-o data=ordered'

	case "$action" in
		create)
			[ -e "$mount_file" ] && return 12
			[ -d "$mount_point" ] || return 13
			is_owner "$SUDO_USER" "$mount_point" || return 14

			[ "${size: -1:1}" = 'K'  -o  "${size: -1:1}" = 'M' ] || return 15
			sz=$(str2int "${size%?}") || return 15

			[ "${size: -1:1}" = 'M' ] && sz=$((sz*1024))
			offs=$((offset_loop/1024 + offset*512/1024))
			tmp=$min_size
			[ "$fs_type" = 'ext3' ] && tmp=$min_size_ext3

			[ $((offs + tmp)) -le $sz ] || return 16
		;;
		mount)
			[ -f "$mount_file"  ] || return 17
			[ -d "$mount_point" ] || return 13
			[ $(get_mounts "/dev/mapper/$fs" '' /etc/mtab) ] && return 10

			is_owner "$SUDO_USER" "$mount_file"  || return 18
			is_owner "$SUDO_USER" "$mount_point" || return 14
		;;
		umount)
			[ -e "$mount_file"  ] && [ ! -f "$mount_file"  ] && return 17
			[ -f "$mount_file"  ] && \
				! is_owner "$SUDO_USER" "$mount_file" && return 18
			[ -b "/dev/mapper/$fs" ] && \
				[ "$(ls -l "/dev/mapper/$fs" \
				| awk '{print $3}')" != "$SUDO_USER" ] && return 19
		;;
	esac
	return 0
}

is_owner ()	# user file
{
	[ "$(ls -ld $2 | awk '{print $3}')" = "$1" ] || return 1
	[ "$(ls -ld $2 | awk '{print $4}')" = "$1" ] || return 1
}

map_file ()
{
	local dev_loop='' es=0

	sync
	[ -b "/dev/mapper/$fs" ] && return 0
	[ ! -e "/dev/mapper/$fs" ] || return 51

	dev_loop=$(/sbin/losetup -sfo "$offset_loop" "$mount_file") || return 52
	/sbin/cryptsetup -c "$cipher" -o "$offset" \
		create "$fs" "$dev_loop" || { umap_file; return 53; }
	sleep 1
	chown "$SUDO_USER" "/dev/mapper/$fs" || { umap_file; return 54; }
	sync
}

umap_file ()
{
	local dev_loop='' i='' es=0

	sync
	[ -b "/dev/mapper/$fs" ] && { /sbin/cryptsetup remove "$fs" || return 41; }
	[ ! -e "/dev/mapper/$fs" ] || return 42

	dev_loop=$(/sbin/losetup -a | sed -n \
		s#^\\\(/dev/loop[0-9]\\\{1,\\\}\\\).*\($mount_file\).*\$#\\1#p) || return 43

	for i in $dev_loop; do
		/sbin/losetup -d "$i" || return 44
	done
	sync
}

feedback ()
{
	return 0
} >&2

usage ()
{
	echo "
Usage:
$ME:  This is a system program.
$ME:  Please do not call it directly.
$ME:  Thanks!
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
	must_be_installed -s

	dst=$(readlnk -- "$dst")			|| ! echo "Cannot resolve $dst"	|| es=26

#	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving


	get_cmd_line_parameters "$@" || es=1
	get_configuration_settings   || es=1
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

