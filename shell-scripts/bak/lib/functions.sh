
# Functions library
# Author: Georgi Kovachev
# Version=1.1.8


# program wide configuration start ------------
# LOGFILE='/var/log/kassandra/kassandra.log'	# general log file for kassandra utilities
# trap trap_on_exit 0				# set trap on EXIT
# program wide configuration end ==============


# Called by trap on EXIT
# Input:  None
# Output: None
# Exit status: 0
trap_on_exit ()
{
	shell_exit_status=$?	# catch shell exit status

	log Exit status $es \ Shell exit status: $shell_exit_status
}

# Append message to log file
# Input:  $@          - message
#         $LOGFILE    - log file
#         $LOGPREFIX  - message prefix, parsed by eval
#         $LOGSUFFIX  - message suffix, parsed by eval
# Output: None
# Exit status: 0
# Comments:
# Message is appended when $LOGFILE is set and accessible
# Log file is created if directory exists
# Default log file: /var/log/kassandra.log
log ()
{
	local lf ld dt

	[ -n "$LOGFILE"  -a  -n "$*" ]		|| return 0

	lf=$LOGFILE
	if [ ! -e "$lf" ]; then
		lf=$(readlink -f -- "$lf")	&& \
		ld=$(dirname "$lf")		&& \
		[ -d "$ld"  -a  -w "$ld"  -a  -x "$ld" ] && \
		touch "$lf"			|| \
			{
				lf='/var/log/kassandra.log'	# default
				touch "$lf"	|| return 0
				chmod 640 "$lf"	|| return 0
			}
	fi
	[ -f "$lf"  -a  -w "$lf" ]		|| return 0

	dt=$(date +%Y.%m.%d-%H:%M:%S)		|| dt='NA'
	eval echo "[$dt] $ME: $LOGPREFIX '$*' $LOGSUFFIX" >> "$lf"	|| :
}

# Trim white space for pairs "name=value"
# Input:  $1  - string '  par name  =  par value  '
# Output: string 'par name=par value'
#         leading and trailing white spaces are trimmed
#         white space around '=' sign is trimed
#         white space inside both "name" and "value" is unchainged
#         if '=' sign is not present the string is unchaunged
# Exit status: 0
name_eq_value ()
{
	local v nam val

	v=$1
	nam=${v%%=*}
	val=${v#*=}

	[ "$nam" = "$v"  -o  "$val" = "$v" ] && echo -n "$v" && return	# '=' not found

	# trim leading and trailing white space
	nam=$(echo "$nam" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
	val=$(echo "$val" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')
	echo -n "${nam}=${val}"						# exit status 0
}

# Return directory entry types
# Input:  $1  - directory
# Output: types of directory entries, bit encoded, excluding . and ..
#         res.b4  - does not exist       (output 16)
#         res.b3  - non directory exists (output  8)
#         res.b2  - ..name (2 leading dots)
#         res.b1  - .name  (1 leading dot)
#         res.b0  - name   (no leading dots)
# Exit status: 0
dir_entry_types ()
{
	local r

	r=0
	[ "$(echo "$1"/..?*)"   != "$1/..?*"   ] || [ -e "$1/..?*"   ]	&& r=$((r+4))
	[ "$(echo "$1"/.[!.]*)" != "$1/.[!.]*" ] || [ -e "$1/.[!.]*" ]	&& r=$((r+2))
	[ "$(echo "$1"/[!.]*)"  != "$1/[!.]*"  ] || [ -e "$1/[!.]*"  ]	&& r=$((r+1))
	[ -d "$1"  -a  ! -h "$1" ]					|| r=8
	[ -e "$1" ]							|| r=16
	echo -n $r
}

# Show version string and exit
# Input:  None
# Output: version string
# Exit status: exit with 0
version ()
{
	echo "$ME $Version"
	exit 0
}

# Ensure root permissions are granted
# Input:  None
# Output: None
# Exit status: 0 if success, exit with 1 if error
must_be_root ()
{
	if [ "$(/usr/bin/id -u)" != "0" ]; then
		echo "$ME: You must be root to run this script." >&2
		exit 1
	fi
}

# Search the PATH for executable files matching the names of the arguments
# Input:  $@  - [-Ds] filename ...
#         -D  - no defaults
#         -s  - include system commands
# Output: None
# Exit status: 0 if success, exit with 1 if error
must_be_installed ()
{
	local D s es i list
	local bin_def  usr_bin_def  sbin_sys  bin_sys  usr_sbin_sys  usr_bin_sys

	# defaults
	bin_def="cat cp date grep ln ls mkdir mountpoint mv rm rmdir \
		sed sleep sync touch"
	usr_bin_def='/usr/bin/id awk base64 cmp find rev sha512sum sort stat tac'

	# system
	sbin_sys='losetup'
	bin_sys='chmod chown dd df mount umount stty'
	usr_sbin_sys=''
	usr_bin_sys='shred sudo'

	getoptions Ds "$@" && shift $((OPTIND-1))		|| exit 1

	[ -x /bin/which  -o  -x /usr/bin/which ] && es=0	|| \
	! echo "$ME: Error: Cannot find command 'which'"	|| exit 1

	list="${s:+$sbin_sys $bin_sys $usr_sbin_sys $usr_bin_sys}"
	[ -z "$D" ] && list="$bin_def $usr_bin_def $list"

	which $list "$@" >/dev/null 2>&1	&& return 0	# optimization

	for i in $list "$@" ; do
		which "$i" >/dev/null 2>&1	|| ! es=1	|| \
			! echo "$ME: Error: Cannot find command '$i'"
	done
	[ $es -eq 0 ]	|| exit 1
}

# Load required files
# Input:  $@  - library files list
#         $@  - [-f file] -- command line parameters (single file only)
# Output: None
# Exit status: 0 if success, exit with 1 if error
load_libs ()
{
	local f file keep keep_PWD keep_OLDPWD ME SELF

	keep_PWD=$PWD
	keep_OLDPWD=$OLDPWD
	keep=$(pwd)
	ME=$(basename       -- "$0")		# program name as invoked
	SELF=$(readlink -ve -- "$0") || exit 1	# /absolute/path/program
	cd  "$(dirname      "$SELF")"		# navigate to self directory
						# for link resolving
	getoptions f: "$@" && shift $((OPTIND-1))	|| exit 1

	while [ $# -ne 0  -o  -n "$f" ]; do
		[ -n "$f" ] && file=$f || file=$1
		if [ -n "$file" ]; then
			file=$(readlnk    -- "$file")  && \
			[ -f "$file"  -a  -r "$file" ] && . "$file" "$@" || \
			{
				echo -n "$ME: FATAL ERROR: $file"	>&2
				echo " cannot be loaded. Aborting."	>&2
				exit 1
			}
		fi
		[ -n "$f" ]	&& break
		shift
	done
	cd -- "$keep"				# restote working directory
	OLDPWD=$keep_OLDPWD
	PWD=$keep_PWD
}

# If option -m is not supported by readlink command, use option -f
# Input:  $@  - [-P] -- link_name, e.g. ../../dir/linkname
#         -P  - no dereference - never follow symbolic links
# Output: absolute link destination, e.g. /absolute/path/filename
#         $1 unchanged (dead link or cannot be resolved) - if error
# Exit status: 0 if success, greater than 0 if error
readlnk ()
{
	local P lnk bn skip res

	getoptions P "$@" && shift $((OPTIND-1))	|| return 1
	lnk=$1
	res=${1:-'-'}

	if [ -z "$P" ] && [ "$res" != '-'  -o  -e "$res"  -o  -h "$res" ]; then
		res=$(readlink -m -- "$res" 2>/dev/null  || \
		      readlink -f -- "$res" 2>/dev/null) || ! echo -n "$1" || return 2
		lnk=$res
		while [ "$lnk" != '/' ]; do
			lnk=$(dirname -- "$lnk")
			if [ -e "$lnk" ]; then
				[ -d "$lnk" ] && break	 || ! echo -n "$1" || return 1
			fi
		done
	fi
	if [ -n "$P" ]; then
		[ "${lnk#/}" = "$lnk" ] && lnk=$(pwd)/$lnk
		res='/'
		skip=0
		while [ "$lnk" != '' ]; do
			lnk=${lnk%${lnk##*[!/]}}
			bn=${lnk##*/}
			lnk=${lnk%"$bn"}
			case "$bn" in
				..)	skip=$((skip+1))	;;
				.?* | [!.]*)
					[ $skip -eq 0 ] && \
					res=/${bn}${res%'/'}	|| skip=$((skip-1))
				;;
			esac
		done
	fi
	echo -n "$res"
}
# Deprecated, use "readlnk"
# Link must be valid
readlink_mf ()
{
	local res

	res=$(readlink -m "$1" 2>/dev/null) || \
	res=$(readlink -f "$1" 2>/dev/null) || return 1

	echo "$res"
}

# Verify if the path containes the tree
# Input:  $@  - [-P] -- path tree_root_directory
#         -P  - no dereference - never follow symbolic links
# Output: None
# Exit status: 0 if success, greater than 0 if error
# Examples:
# contains_tree  /d1/d2  /d1/d2/d3   # /d1/d2  contains tree          /d1/d2/d3
# contains_tree  /d1/d2  /d1/d4/d5   # /d1/d2  does not contain tree  /d1/d4/d5
contains_tree ()
{
	local P path dir subdir

	getoptions P "$@" && shift $((OPTIND-1))	|| exit 1

	[ -n "$1"  -a  -n "$2" ]			|| return 0
	path=$(readlnk ${P:+'-P'} -- "$1")
	dir=$(readlnk  ${P:+'-P'} -- "$2")/

	subdir=${dir#"${path%/}/"}
	[ "$subdir" != "$dir" ]
}

# Create directory with unique name
# Input:  $1  - prefix, e.g. /path/[part name]
#         $2  - suffix, e.g. .tmp
#         $3  - random string length in symbols
# Output: directory name  - if success
# Exit status: 0 if success, greater than 0 if error
mk_tmp_dir ()
{
	local dir i try

	try=256
	i=0
	while [ $i -lt $try ]; do
		dir=$1$(random_string "$3")$2 && [ -n "$dir" ]	|| return 1
		mkdir -m 700 -- "$dir" 2>/dev/null && break
		i=$((i+1))
	done
	[ $i -ne $try ]	&& echo -n "$dir"
}

# Validate filename depending on filesystem
# Input:  $1  - absolute filename specification, e.g. /absolute/path/filename
# Output: None
# Exit status: 0 if success, greater than 0 if error
valid_fname ()
{
	local dir file es tmp

	dir=$(dirname   -- "$1")
	file=$(basename -- "$1")
	es=0

	# create tmp directory on target filesystem
	tmp=$(mk_tmp_dir "${dir}/V-" .tmp 6)	|| return 1
	mkdir  -- "$tmp/$file" 2>/dev/null	|| es=1
	rm -fr --one-file-system -- "$tmp"	|| return 1	# remove tmp directory
	[ $es -eq 0 ]				# 0 if success, 1 if error (true/false)
}

# Create backup copies of file or directory by adding
# prefix, suffix and version number starting from 1
# Tne bigger the version number the oldest the backup copy
# Input:  $1  - destination file or directory
#         $2  - prefix
#         $3  - suffix
#         $4  - backups copies count from 0 to 99 (0 means no backup)
# Output: None
# Exit status: 0 if success, greater than 0 if error
rotate_backups ()
{
	local dest_file pref suff bkps i backup_file

	dest_file=$1
	pref=$2
	suff=$3
	bkps=$(str2int "$4")		|| return 1

	backup_file=$(dirname -- "$dest_file")/${pref}$(basename -- "$dest_file")${suff}
	valid_fname "$backup_file"	|| return 1

	if [ -e "$dest_file" ]; then
		i=1
		while [ $i -lt $bkps ] && [ -e "${backup_file}$i" ]; do
			i=$((i+1))
		done

		# ensure the file does not exist - must!
		[ $i -ne $bkps ] || \
			rm -fr --one-file-system -- "${backup_file}$i"		|| return 1
		while [ $i -gt 1 ]; do
			mv -f -- "${backup_file}$((i-1))" "${backup_file}$i"	|| return 1
			i=$((i-1))
		done
		[ $bkps -eq 0 ] || mv -f -- "${dest_file}" "${backup_file}1"	|| return 1
	fi	# exit status 0
}

# Get correspondence between device and mount point
# Input:  $1, $2  - device name or mount point (e.g. /dev/hda1 or /mnt)
#	  $3      - file list (e.g. /etc/fstab, /etc/mtab, /proc/mounts)
# Output: device name or mount point (e.g. /dev/hda1 or /mnt)
#	  returns the last entry if found, empty string otherwise
# Exit status: 0 if success, greater than 0 if error
# Examples:
# get_mounts /dev/hda1 ''        /etc/mtab	; result: /mnt/hda1 - mount point
# get_mounts /mnt/hda1 ''        /etc/mtab	; result: /mnt/hda1 - mount point
# get_mounts ''        /dev/hda1 /etc/mtab	; result: /dev/hda1 - device
# get_mounts ''        /mnt/hda1 /etc/mtab	; result: /dev/hda1 - device
# get_mounts /dev/hda1 /dev/hda1 /etc/mtab	; result: /mnt/hda1 - mount point
# get_mounts /mnt/hda1 /mnt/hda1 /etc/mtab	; result: /dev/hda1 - device
# get_mounts /dev/hda1 /mnt/hda1 /etc/mtab	; result: /mnt/hda1 - mount point
# get_mounts /mnt/hda1 /dev/hda1 /etc/mtab	; result: /dev/hda1 - device
get_mounts ()
{
	local p1 p2

	p1=$1
	p2=$2
	shift 2

	sync
	awk -v p1="$p1" -v p2="$p2"	'
	{
		sub(/^[ \t]*#.*/, "")	# remove entire commented lines
		if ((p1 == $1) && ((p2 == "") || (p2 == $1)))	res = $2
		if ((p1 == $2) && ((p2 == "") || (p2 == $1)))	res = $2
		if ((p2 == $1) && ((p1 == "") || (p1 == $2)))	res = $1
		if ((p2 == $2) && ((p1 == "") || (p1 == $2)))	res = $1
		if ((p1 == $1) && ((p2 == "") || (p2 == $2)))	res = $2
	}
	END	{	print res	}
	' "$@"
}

# Remove comments and blank lines from file,
# trim white space at the beginning and the end of line,
# join braked lines
# comments begin with '#' mark
# Input:  $1  - file
# Output: file entry without comments and blank lines,
#         white space trimmed, braked lines are joined - if success
# Exit status: 0 if success, greater than 0 if error
remove_comments_from_file ()
{
	awk '
	{
		ORS = "\n"
		sub(/^[ \t]*#.*/, "")	# remove entire commented lines
		sub(/[ \t]+#.*$/, "")	# remove comments at the end of line

		sub(/^[ \t]*/, "")	# trim white space at the beginning
		sub(/[ \t]*$/, "")	# trim white space at the end

		if (/\\$/)		# join braked lines
		{
			sub(/\\$/, "")
			ORS = ""
		}

		if (NF)			# if line is not blank
			print		# output $0 to stdout
	}' "$@"
}

# Write prompt message to stderr and wait for user input
# Input:  $@ - [options]
#         -n neg     - negative answer
#         -o pos     - positive answer
#         -p prompt  - prompt message
#         -r rpt     - ask rpt times if invalid answer is given [1-9]
#         -t         - terminate if no positive answer is given
#         -y         - assume 'yes' to all questions (same as -r 0, overrides -r)
# Output: None
# Exit status: 0 if success, greater than 0 if error
# Comments:
# Prompt message is writen if option -y is not supplied
# Examples:
# fb_prompt -t -p 'Prompt here'
# fb_prompt -to YES -n '[Nn]o' -r 2 -p 'Prompt here'
fb_prompt ()
{
	local ans es n o p r t y

	getoptions n:o:p:r:ty "$@"	|| return 4

	[ -n "$y" ]			&& return 0
	case "$r" in
		[0-9])	[ $r -eq 0 ]	&& return 0	;;
		*)	r=1				;;
	esac

	es=3
	while [ $r -gt 0  -a  $es -eq 3 ]; do
		if read -p "${p:-"    OK to proceed? [Yes|No] (default No): "}" ans ; then
			case "$ans" in
				"${n:-"No"}")	es=2	;;
				"${o:-"Yes"}")	es=0	;;
			esac
		else
			echo '^D'
			echo "$ME: User canceled operation."
			es=1
		fi
		r=$((r-1))
	done
	if [ $es -eq 1 ] || [ $es -ne 0  -a  -n "$t" ]; then
		echo "$ME: Terminating..."
		echo ''
		exit $es
	fi
	return $es
} >&2

# Validate integer value [+|-][0-9]
# Input:  $1  - integer value, decimal
# Output: integer value, decimal, no leading zeros - if success
#         $1 unchanged (not a valid integer, cannot be converted) - if error
# Exit status: 0 if success, greater than 0 if error
# Examples:
# input value	output value	exit status
# 0 -0 +0	0		0
# 00 -00 +00	0		0
# 9 +9 +009	9		0
# 0123 +0123	123		0
# -120 -0120	-120		0
# 123c5		123c5		1
# 12 45		12 45		1
str2int ()
{
	local res i v c es d

	v=$1
	v=${v#${v%%[! 	]*}}	# trim white space at the beginning
	v=${v%${v##*[! 	]}}	# and end of the input (space or tab)
	c=${#v}			# count charicters
	res='+'
	es=0

	i=0
	while [ $i -lt $c ]; do
		d=${v%"${v#?}"}
		v=${v#?}
		case $d in
			-|+)	[ $i -eq 0 ] && res=$d || { es=1; break; }		;;
			0)	[ ${#res} -ne 1  -o  $i -eq $((c-1)) ] && res=${res}0	;;
			[1-9])	res=$res$d						;;
			*)	{ es=1; break; }					;;
		esac
		i=$((i+1))
	done
	[ ${#res} -eq 1 ] && es=1						# only '+' or '-'
	res=${res#+}
	[ "$res" = '-0' ] && res=0
	[ $es -ne 0 ]	|| \
		( i=$((res + 0)) 2>/dev/null ; [ "$res" = "$i" ] ) || es=2	# is too big?
	[ $es -eq 0 ]	  && echo -n $((res + 0))	|| echo -n "$1"	&& return $es
}

# Get random string
# Input:  $1  - length in symbols
#         $2  - symbols allowed (optional)
# Output: random string [0-9][a-z][A-Z] or from "$2" set if supplied
# Exit status: 0 if success, greater than 0 if error
random_string ()
{
	local	chr len rnd sum mask i

	chr='0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

	len=$(str2int "$1")	|| return 1
	[ -n "$2" ] && chr=$2

	[ -x /bin/date ] && sum=$(date +%N 2>/dev/null) || sum=0	# init
	sum=$(str2int "$sum")	|| return 2

	sum=$((sum + ${PPID}000 + ${$} + 1000000000 + RANDOM))		# 9 digits
	RANDOM=$(( (sum + ${sum%???}) & 0x7FFF ));

	i=0
	while [ $i -lt $len ]; do
		sum=${sum#?}
		sum=$((1${sum#?}${sum%????????} + 2${sum%??} + i + RANDOM)) # rol + ...
		rnd=$((sum % ${#chr}))

		mask=''
		while [ $rnd -gt 0 ]; do
			mask=$mask'?'
			rnd=$((rnd - 1))
		done

		printf %c "${chr#$mask}"
		i=$((i+1))
	done
}

# Obtain options and their arguments from a list of parameters
# Input:  $1        - optstring
#         $2..\$$#  - [options] [parameters]
# Output: None
#         OPTIND shell variable is set to the index of the first non-option parameter
# Exit status: 0 if success, greater than 0 if error
# Comments:
# optstring is compatible with getopts shell builtin
# In addition if an option requires an argument and is repeated, then all arguments
# specified for this option are joined in a list and separated by new line (0x0A)
# All arguments are placed in variables with the same names as options
# If an option is a digit [0-9] the corresponding variable is prafixed with underscore (_)
# All variables are initialized to empty string
# If an option does not require an argument the corresponding variable is set to the
# option name, e.g. if option -aa is specified, variable a set to value aa will exist
# Examples:
# getoptions ab:c:c: -aab bvalue -c cvavue1 -c cvalue2 -c cvalue3
getoptions ()
{
	local es optstr opt os

	optstr=$1
	shift

	es=0
	os=$optstr
	while [ -n "$os" ]; do
		opt=${os%"${os#?}"}
		os=${os#?}
		case "$opt" in
			[a-zA-Z])	eval $opt=''			;;
			:)		continue			;;
			[0-9])		eval '_'$opt=''			;;
			*)		es=1				;;
		esac
	done

	OPTIND=1
	[ "${1#--?}" = "$1" ]		|| return $es

	while getopts "$optstr" opt ; do
		os=$opt
		case "$opt" in
			[0-9])		opt='_'$opt			;;
			[!a-zA-Z])	es=1	;	continue	;;
		esac

		if [ "${optstr#*"$os":}" = "$optstr" ]; then
			eval $opt=\$$opt"'$os'"
		else
			if [ "${optstr#*"$os":"$os":}" = "$optstr" ]; then
				eval $opt="'$OPTARG'"
			else
				eval $opt=\$$opt"'$OPTARG
'"	# new line
			fi
		fi
	done
	return $es
}

# Verify if argument is a shell function
# Input:  $1  - function name
# Output: None
# Exit status: 0 if success, greater than 0 if error
is_function ()
{
	local res

	read res <<- EOF
		$(command -V "$1" 2>/dev/null)
	EOF
	[ "${res#${res%function}}" = 'function' ]
}

# Evaluate enable status
# Input:  $1        - enable level local [0-9], if present
#         \$$#      - enable level global [0-9], if present
# Output: None
# Exit status: 0 if success, greater than 0 if error
# Comments:
# Enable is get when \$$# is equal to or grater then $1,
# except for the case when $1 is 0
# If \$$# is not in range [0-9] or unset, then assume it is equal to $1
# $1           = 0  - ultimate disable
# $1           = 5  - default
# \$$#         = 0  - ultimate disable
# \$$#         = 2  - disable
# \$$#         = 7  - enable
is_enabled ()
{
	local lc gl

	case "$1" in
		[0-9])	lc=$1	;;
		*)	lc=5	;;
	esac
	[ $# -ne 0 ] && shift $(($# - 1))

	case "$1" in
		[0-9])	gl=$1	;;
		*)	gl=$lc	;;
	esac

	[ $(( gl*lc * (gl + 1 - lc) )) -gt 0 ]
}

# Show message on standard error or query verbose status
# Input:  $1        - verbose level local (VL) [0-9] and 'echo' option -n, if present
#                     accepted values: -n. [0-9], -n[0-9]
#         $n        - message
#         $VERBOSE  - verbose level global [0-9]
# Output: None
# Exit status: 0 if success, greater than 0 if error
# Comments:
# Message is shown when $VERBOSE is equal to or grater then VL,
# except for the case when VL is 0
# If $VERBOSE is not in range [0-9] or unset, then assume it is equal to VL
# $1           = 0  - ultimate disable
# $1           = 5  - default
# $VERBOSE     = 0  - ultimate disable
# $VERBOSE     = 2  - disable
# $VERBOSE     = 7  - enable
# If message is specified, then show it and return 0,
# else return verbose status
vrb ()
{
	local vlc opt

	vlc=5
	opt=''
	case "$1" in
		[0-9])		vlc=$1   ;	shift	;;
		-n)		opt='-n' ;	shift	;;
		-n[0-9])	vlc=${1#'-n'}
				opt='-n' ;	shift	;;
		'')		[ $# -ne 0 ] && shift	;;
	esac

	if is_enabled "$vlc" "$VERBOSE" ; then
		[ $# -ne 0 ] && echo $opt "$@" >&2	|| :
	else
		[ $# -ne 0 ]				# query verbose status
	fi
}

# Execute the command string or query execute status
# Input:  $1        - execute level local [0-9], if present
#         $n        - command string
#         $EXECUTE  - execute level global [0-9]
# Output: depends on the command string executed
# Exit status: depends on the command string executed
# Comments:
# The command string is executed when $EXECUTE is equal to or grater then $1,
# except for the case when $1 is 0
# If $EXECUTE is not in range [0-9] or unset, then assume it is equal to $1
# $1           = 0  - ultimate disable
# $1           = 5  - default
# $EXECUTE     = 0  - ultimate disable
# $EXECUTE     = 2  - disable
# $EXECUTE     = 7  - enable
# If command string is specified, then execute it,
# else return execute status
exc ()
{
	if is_enabled "$1" "$EXECUTE" ; then
		case "$1" in
			[0-9] | '')	[ $# -ne 0 ] && shift	;;
		esac

		if [ $# -eq 1  -a  -n "$1" ]; then	# execute command
			eval "$@"
		else
			"$@"
		fi
	else
		case "$1" in
			[0-9] | '')	[ $# -ne 0 ] && shift	;;
		esac

		[ $# -ne 0 ]				# query execute status
	fi
}

# Show debug information on standard error and execute the command string
# Input:  $1        - debug level local [0-9], if present
#         $n        - command string
#         $VERBOSE  - verbose level global [0-9]
#         $EXECUTE  - execute level global [0-9]
# Output: depends on the command string executed
# Exit status: depends on the command string executed
# Comments:
# See descriptions for vrb end exc
dbg ()
{
	vrb "$@"			|| :		# show commald line
	! is_enabled "$1" "$EXECUTE"	|| exc "$@"	# execute command
}

# Show execution time
# Input:  $@  - command string
# Output: depends on the command string executed
# Exit status: depends on the command string executed
stm ()
{
	local time_TShTx9Ec7c9OHdUM es_z1TShTx9Ec7c9OHdUM

	time_TShTx9Ec7c9OHdUM=$(date +%s%N)

	if [ $# -eq 1  -a  -n "$1" ]; then		# execute command
		eval "$@"
	else
		"$@"
	fi
	es_z1TShTx9Ec7c9OHdUM=$?

	time_TShTx9Ec7c9OHdUM=$(( $(date +%s%N) - time_TShTx9Ec7c9OHdUM ))

	printf %.2d:	$((   time_TShTx9Ec7c9OHdUM / 3600000000000                 ))	>&2
	printf %.2d:	$(( ( time_TShTx9Ec7c9OHdUM % 3600000000000 ) / 60000000000 ))	>&2
	printf %.2d.	$(( ( time_TShTx9Ec7c9OHdUM %   60000000000 ) / 1000000000  ))	>&2
	printf %.3d'\n'	$(( ( time_TShTx9Ec7c9OHdUM %    1000000000 ) / 1000000     ))	>&2

	return $es_z1TShTx9Ec7c9OHdUM
}








