

# Functions library
# Author: Georgi Kovachev
# Version=1.0.15

# belongs to 'bak' script
# 
# 
# 

key_db ()	# copy | remove
{
	[ -f "$key_script"  -a  -x "$key_script" ]		|| return 0
	case "$1" in
		copy)		"$key_script" copytree "$dst"	|| :	;;
		remove)		"$key_script" block    "$dst"	|| :	;;
		*)		return 1				;;
	esac
} >&2

remove_dst_tree ()
{
	[ "$src" = '-' ]			&& return 0
	[ "$(dir_entry_types "$dst")" = '0' ]	&& return 0

	echo "$ME: Removing tree $dst/*"
	echo "$ME: WARNING: ALL DATA WILL BE REMOVED!"
	echo "$ME: WARNING: NO RECOVERY AVAILABLE!"
	fb_prompt $assume_yes -t

	[ -d "$dst" ]				|| return 1

	key_db remove
	dbg rm -fr --one-file-system -- "$dst"/* "$dst"/.[!.]* "$dst"/..?*
	sync
} >&2

is_system ()
{
	[ -n "$src"      ]	&&			   \
	[ -d "$src/boot" ]	&& [ -d "$src/bin"  ]	&& \
	[ -d "$src/dev"  ]	&& [ -d "$src/lib" ]	&& \
	[ -d "$src/proc" ]	&& [ -d "$src/sbin" ]	&& \
	[ -f "$src/etc/fstab" ]	&& [ -h "$src/vmlinuz"   ]
}

is_file_busy ()
{
	if tmp=$(/sbin/losetup -a 2>/dev/null); then
		m=$(echo "$tmp" | sed -n \
			"s#^\(/dev/loop[0-9]\{1,\}\).*($obj).*\$#\1#p") || es=3
	else
		echo "$ME: WARNING: Cannot verify if file is busy"
		err 30 "for  $obj"
		fb_prompt $assume_yes && es=0	|| es=3
	fi
} >&2

get_type ()
{
	local es obj t tmp

	obj=$1
	t=${2:-'f'}
	m=''

	[ "$obj" = '-' ] && t='-'
	[ ! -e "$obj" ] && cmd_types=${cmd_types}$t && return 0

	t=''
	[ -f "$obj" ]	&& t='f'
	[ -b "$obj" ]	&& t='b'
	[ -d "$obj" ]	&& t='d'
	cmd_types=${cmd_types}$t

	es=0
	case "$t" in
		f)
			is_file_busy
			[ -r "$obj" ] || es=2
		;;
		b)
			m=$(get_mounts "$obj" "$obj" /etc/mtab)
			if [ -r "$obj" ]; then
				tmp=$(dd count=1 if="$obj" 2>/dev/null | base64 -w0)
				[ -n "$tmp" ] || es=2
			else
				es=2
			fi
			[ -w "$obj" ] || es=$((es+4))
		;;
		d)
			[ -r "$obj" ] || es=2
			[ -w "$obj" ] || es=$((es+4))
		;;
		*)
			es=1
		;;
	esac

	return $es
}

analyse ()
{
	local s d sm dm m t

	s=$src
	d=$dst
	[ "$src" = '-' ] || [ -e "$src" ]		|| err 12, 36
	t=''
	cmd_types=${cmd%${cmd#?}}

	get_type "$src"			|| err 40
	[ -z "$m" ] && sm=0		|| { sm=1 ; err 50 "on $m" ; }
	[ $es -eq 0 ]			|| return $es

	case "${cmd_types}${d}" in
		??-)	:							;;
		cf*)
			dst=${dst%.gpg}.gpg
			bak_type='file'
		;;
		cb*)
			dst=${dst%.gpg}
			dst=${dst%.img}.img.gpg
			bak_type='image'
		;;
		cd*)
			dst=${dst%.gpg}
			if is_system; then
				dst=${dst%.sys}.sys.gpg
				bak_type='system'
			else
				dst=${dst%.dir}.dir.gpg
				bak_type='directory'
			fi
		;;
		rf*)
			bak_type=${src%.*}
			bak_type=${bak_type#${bak_type%.*}}${src#${src%.*}}
			case "$bak_type" in
				.sys.gpg | .dir.gpg)	t='d'			;;
			esac
		;;
	esac

	get_type "$dst" "$t"		|| err 41
	[ -z "$m" ] && dm=0		|| { dm=1 ; err 51 "on $m" ; }
	[ $es -eq 0 ]			|| return $es

	case "$cmd_types" in
		??f)		[ ! -e "$dst" ]			|| err 53	;;
	esac
	case "$cmd_types" in
		?[!-][!-])	[ "$src" != "$dst" ]		|| err 52	;;
	esac

	case "$cmd_types" in
		rff)
			case "$bak_type" in
				.gpg)		bak_type='file'			;;
				.img.gpg)	bak_type='image'		;;
				*)		err 19 "$bak_type for $dst"	;;
			esac
		;;
		rfb)
			[ "$bak_type" = '.img.gpg' ]	|| err 19 "$bak_type for $dst"
			bak_type='image'
		;;
		rfd)
			case "$bak_type" in
				.sys.gpg)
						[ -e "$dst" ]	|| err 13, 36
						bak_type='system'
				;;
				.dir.gpg)	bak_type='directory'		;;
				*)		err 19 "$bak_type for $dst"	;;
			esac
		;;
		c?[-f] | r-? | rf-)	:					;;
		c?[bd])		err 11 "Illegal destination $dst"		;;
		r[bd]?)		err 11 "Illegal source $src"			;;
		*)		err 127						;;
	esac

	case "$bak_type" in
		file | image | system | directory)	:			;;
		*)		bak_type='not set'				;;
	esac
	case "$cmd_types" in
		?[!b]?)		cleanup='NA'					;;
	esac

	contains_tree "$dst" /home && target_type='home'	|| target_type='ordinary'

	return $es
}

encryption_handler ()
{
	local pf rpt

	[ x${cmd_types%??} = 'xc' ] && rpt=2 || rpt=1

	if [ -f "$key_script"  -a  -x "$key_script" ]; then
		pf=$("$key_script" $key_get_prefix secure_device,passwd-rpt="$rpt" "$config_file")
	else
		pf=$(km_get_passwd "$rpt")
	fi

	case "$cmd_types" in
		c[-fb][-f])
			gpg_encryption -c "$src" "$dst" "$pf"
		;;
		cd[-f])
			tar -cvC "$src" . --one-file-system | gpg_encryption -c - "$dst" "$pf"
		;;
		r[-f][-fb])
			gpg_encryption -d "$src" "$dst" "$pf"
		;;
		r[-f]d)
			gpg_encryption -d "$src" - "$pf" | tar -xvpC "$dst" --same-owner
		;;
		*)
			return 1
		;;
	esac
}

modify_fstab ()
{
	local keep_IFS i tmp uc es r d

	keep_IFS=$IFS
	uc=1
	es=9

	trim_beginning ()
	{
		# trim white space and '#' at the beginning
		tmp=$(echo "$i" | sed 's/^[ \t#]*\(.*\)$/\1/')

		# if commented - return 1
		[ -z "$(echo "$i" | sed -n '/^[ \t]*#.*/p')" ]	|| return 1
	}

	# mangle dev
	r=${root%${root#/dev/[hs]d}}
	d=${dev%${dev#/dev/[hs]d}}
	case "${r}_${d}" in
		/dev/hd_/dev/sd | /dev/sd_/dev/hd)	dev=$r${dev#$d}		;;
	esac

	IFS='
'								# new line
	for i in $fstab_entry; do
		if ! trim_beginning ; then			# if commented
			# if /dev/somedevice	/	etc.	etc.
			[ "$(echo "$tmp" | awk '{print $2}')" = '/' ]		&& tmp="skip_$root"

			# if old root device - uncomment
			[ $uc -ne 0 ]	&& [ "$(echo "$tmp" | awk '{print $1}')" = "$root" ]	\
				&& [ "$root" != "$dev" ]	&& i="$tmp"	&& uc=0
		else
			# if /dev/somedevice	/	etc.	etc.
			if [ "$(echo "$tmp" | awk '{print $2}')" = '/' ]; then
				# set new root device
				[ $es -ne 0 ]	&& i=$(echo "$i" | sed s#$root#$dev#)		\
					&& tmp="skip_$dev"	&& es=0
			fi
			# if new root device - comment
			[ "$(echo "$tmp" | awk '{print $1}')" = "$dev" ]	&& i="# $tmp"

			# if old root device uncommented - disable uncomment
			[ $uc -ne 0 ]	&& [ "$(echo "$tmp" | awk '{print $1}')" = "$root" ]	\
				&& uc=0
		fi
		echo "$i"
	done

	IFS=$keep_IFS
	return $es
}

fstab_handler ()
{
	local dev fstab_entry res root dir

	dir=$(get_mounts "$dst" '' /etc/mtab)
	[ -n "$dir" ]					|| return 2	# device not mounted
	fstab=$dir/etc/fstab

	[ -f "$fstab" ]					|| return 1	# is found?

	dev=$(get_mounts '' "$dst" /etc/mtab)
	[ -n "$dev" ]					|| return 2	# device not mounted

	root=$(get_mounts '' '/' "$fstab")
	[ -n "$root" ]					|| return 3	# invalid fstab format

	# read input file
	fstab_entry=$(sed 's/^\(.*\)/\1 1 2/' "$fstab")	|| return 4

	res=$(modify_fstab)				|| return $?

	# write output file
	echo "$res" | sed 's/....$//' > "${fstab}.part"	|| return 5

	mv -S '-bak' "${fstab}.part" "$fstab"		|| return 6
}

fill_fs ()				# dir suorce-device
{
	local dir dev i z_dir free_sp

	dir=$1				# directory
	dev=$2				# /dev/zero, /dev/urandom, ...

	[ -d "$dir"  -a  -w "$dir" ]		|| return 1
	[ -z "$dev"  -o  "$dev" = '-' ] && dev='' || \
	{
		[ -e "$dev"  -a  -r "$dev" ]	|| return 1
		dev="if=$dev"
	}

	free_space ()
	{
		free_sp=$(df -B $1 --sync "$dir" | awk '{if ($4 ~ /^[0-9]+$/) print $4}')
		[ -z "$free_sp" ] && free_sp=0
		[ $free_sp -ne 0 ] && free_sp=$((free_sp - 1))
		echo "$free_sp"
	}
	print_info ()
	{
		if [ -n "$1" ]; then
			echo ''
			df -k --sync "$dir"
		else
			df -k --sync "$dir" | awk '{if ($4 ~ /^[0-9]+$/) print }'
		fi
	}

	print_info 'Show Header'

	# if there is any free space - create unique tmp directory
	z_dir=''
	if [ $(free_space 1K) -ne 0 ]; then
		# get unique temporary directory name on target device
		z_dir=$(mk_tmp_dir "$dir/zd" .tmp 6)
		# reserve directory entry for 1 file, index 0
		touch "$z_dir/zr0.tmp"
	fi

	# fill disk space in files
	i=1				# init index
	while [ $(free_space 8M) -gt 64 ]; do
		# use large blocks
		dd bs=8M count=64 $dev of="$z_dir/zr${i}.tmp" 2>/dev/null
		print_info
		i=$((i+1))		# update index
	done

	# if there is any free space
	if [ $(free_space 1K) -ne 0 ]; then
		# fill file
		dd bs=1K count=$(free_space 1K) $dev of="$z_dir/zr0.tmp" 2>/dev/null
		print_info
	fi

	# free all filled space, even if unique tmp directory does not exist
	rm -fr "$z_dir"
	print_info
} >&2

err ()		{ err_decoder "$@"	; }
err_decoder ()
{
	local o v s d keep_IFS i p

	p=$*
	if [ "${p#*,}" != "$p" ]; then
		keep_IFS=$IFS
		IFS=','
		for i in $p; do
			IFS=$keep_IFS
			err_decoder "$i"
			IFS=','
		done
		IFS=$keep_IFS
		return
	fi
	[ $# -eq 1 ]		&& eval set -- "$@"

	[ "$1" = '-n' ]		&& o=$1 && shift				|| o=''
	i=$(str2int "$1")	&& [ $i -ge 1  -a  $i -le 127 ] && es=$i	|| :
	[ $es -ge 1  -a  $es -le 127 ]						|| return 0

	[ -n "$2" ] && v=$2 || v=''
	[ -n "$3" ] && s=$3 || s=$src
	[ -n "$4" ] && d=$4 || d=$dst


	case $es in
		1)	echo $o "$ME: $es General error. $v"					;;
		127)	echo $o "$ME: $es FATAL ERROR$v"					;;

		10)	echo $o "$ME: Error: $v"						;;
		11)	echo $o "$ME: $es Error: $v"						;;
		12)	echo $o "$ME: $es Error: Source $v $s"					;;
		13)	echo $o "$ME: $es Error: Destination $v $d"				;;
		14)	echo $o "$ME: $es Error: $v is empty"					;;
		15)	echo $o "$ME: $es Error: Illegal parameter $v"				;;
		16)	echo $o "$ME: $es Error: Unexpected parameter $v"			;;
		17)	echo $o "$ME: $es Error: Too ${v:-"many"} parameters"			;;
		18)	echo $o "$ME: $es Error: Invalid ${v:-"command  $cmd"}"			;;
		19)	echo $o "$ME: $es Error: Unsupported type $v"				;;

		20)	echo $o "$ME: $es Error: Cannot $v"					;;
		21)	echo $o "$ME: $es Error: Cannot access $v"				;;
		22)	echo $o "$ME: $es Error: Cannot change $v"				;;
		23)	echo $o "$ME: $es Error: Cannot create $v"				;;
		24)	echo $o "$ME: $es Error: Cannot find $v"				;;
		25)	echo $o "$ME: $es Error: Cannot mount $v"				;;
		26)	echo $o "$ME: $es Error: Cannot read $v"				;;
		27)	echo $o "$ME: $es Error: Cannot remove $v"				;;
		28)	echo $o "$ME: $es Error: Cannot resolve $v"				;;
		29)	echo $o "$ME: $es Error: Cannot write $v"				;;

		30)	echo $o "$ME: Permission denied $v"					;;
		31)	echo $o "$ME: ${v:-'Read'} permission not granted"			;;
		33)	echo $o "$ME: exists and is not a ${v:-"directory"}"			;;
		34)	echo $o "$ME: exists and is not a regular file $v"			;;
		35)	echo $o "$ME: exists and is not a block device $v"			;;
		36)	echo $o "$ME: does not exist $v"					;;
		37)	echo $o "$ME: does not exist or is not a ${v:-"directory"}"		;;
		38)	echo $o "$ME: does not exist or is not a regular file $v"		;;
		39)	echo $o "$ME: does not exist or is not a block device $v"		;;

		40)	echo $o "$ME: $es Error: Cannot access source $v $s"			;;
		41)	echo $o "$ME: $es Error: Cannot access destination $v $d"		;;
		42)	echo $o "$ME: $es Error: Cannot create ${v:-"directory"}  $d"		;;
		43)	echo $o "$ME: $es Error: Cannot remove ${v:-"directory"}  $d"		;;
		44)	echo $o "$ME: $es Error: Cannot read from $v $s"			;;
		46)	echo $o "$ME: $es Error: Cannot resolve source ${v:-"link"}  $s"	;;
		47)	echo $o "$ME: $es Error: Cannot resolve destination ${v:-"link"}  $d"	;;
		48)	echo $o "$ME: $es Error: Cannot unmount ${v:-"directory"}  $d"		;;
		49)	echo $o "$ME: $es Error: Cannot write to $v $d"				;;

		50)	echo "$ME: $es Error: Source  $s is busy $v"				;;
		51)	echo "$ME: $es Error: Destination  $d is busy $v"			;;
		52)	echo "$ME: $es Error: Source and Destination are the same $v"
			echo "$ME: Source:       $s"
			echo "$ME: Destination:  $d" 						;;
		53)	echo "$ME: $es Error: Destination $v $d exists. Will NOT overwrite it!"	;;

		*)	echo "$ME: $es No message is written for this exit status."		;;
	esac >&2
}

feedback ()
{
	case "${1}-$es" in
		--on-load-0)
			if [ "$cmd" = 'create'  -o  "$cmd" = 'restore'  -o  "$cmd" = 'copy'  -o  \
			     "$cmd" = 'fstab'  -o  "$cmd" = 'cleanup' ]; then
				echo "$ME: Summary:"
				echo "    Command:      $cmd"
				echo "    Source:       $src		$s_dev_msg"
				echo "    Destination:  $dst		$d_dev_msg"
				echo "    Backup type:  $bak_type"
				[ "$cmd" = "create"  -o  "$cmd" = 'cleanup' ] && \
					echo "    Cleanup:      $cleanup"
				echo "    Assume Yes:   ${assume_yes:-no}"
				[ "$cmd" = 'create'  -o  "$cmd" = 'restore' ] && \
					echo "    Config file:  $config_file" && \
					echo "    Target type:  $target_type" && \
					echo "    Flags:        $cmd_types"
				echo ''
				fb_prompt $assume_yes -t
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
			echo ''
			echo "$ME: ERRORS FOUND"
		;;
		--on-xxxx-0)
			:
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
$ME  [-cfy] create  -|file|device|dir  -|bak-file         # create backup
$ME  [-fy]  restore -|bak-file         -|file|device|dir  # restore from backup
$ME  [-y]   copy    dir                dir                # copy directory
$ME  [-y]   fstab   device|dir                            # modify fstab
$ME  [-y]   cleanup device|dir                            # clear unused space
Options:
    -c         - cleanup
    -f         - alternative config file
    -n         - dry run
    -v         - verbose
    -y         - assume 'yes' to all questions
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
		0)	err 17 few			;;
		1|2|3)
			src=$2			# source
			dst=$3			# destination
		;;
		*)	err 17				;;
	esac
	[ $es -eq 0 ]	|| return $es

	[ -n "$f" ]			&& config_file=$f
	[ -n "$c" ]			&& cleanup='yes'	|| cleanup='no'
	assume_yes=${y:+'-y'}

# Check if the configuration satisfy the requirements
	must_be_installed -s
	key_script=$(find_key_script)	|| :

	src=$(readlnk -- "$src")				|| err 46
	dst=$(readlnk -- "$dst")				|| err 47
	config_file=$(readlnk -- "$config_file")		|| err 28 "$config_file"
	[ -f "$config_file"  -a  -r "$config_file" ]		|| err 26 "$config_file"

#	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving

	case "$cmd" in
		create|restore)
			must_be_installed -D tar gpg
			analyse					|| es=$?
		;;
		copy)
			must_be_installed -D tar
			[ "$src" != '-'  -a  "$dst" != '-' ]	|| err 15 "'-'"
			[ "$src" != "$dst" ]			|| err 52
			[ -d "$src" ]				|| err 12, 37

			if is_system; then
				[ -d "$dst" ]			|| ! err 13, -n 37 \
						|| echo ". Source type is 'system'"
				bak_type='system'
			else
				[ -d "$dst"  -o  ! -e "$dst" ]	|| err 13, 33
				[ -w "$dst"  -o  ! -d "$dst" ]	|| err 49, 30
				bak_type='directory'
			fi
		;;
		fstab)
			dst=$src
			[ "$dst" != '-' ]			|| err 15 "'-'"
			bak_type=$cmd
		;;
		cleanup)
			tmp=$dst ; dst=$src ; src=$tmp
			[ -n "$3" ]	|| src='/dev/zero'
			[ "$src" = '-'  -o  -e "$src" ]		|| err 12, 36
			[ "$dst" != '-' ]			|| err 15 "'-'"
			[ -b "$dst"  -o    -d "$dst" ]		|| err 13, "39 'or directory'"
			[ -w "$dst"  -o  ! -e "$dst" ]		|| err 49, 31 'Write'
			bak_type=$cmd
			cleanup='yes'
		;;
		*)	err 18	;;
	esac

	[ "$src" = '-' ]	&& assume_yes='-y'

	s_dev_msg=$(get_mounts "$src" "$src" /etc/mtab)		|| return 1
	[ -n "$s_dev_msg" ]	&& s_dev_msg=\($s_dev_msg\)

	d_dev_msg=$(get_mounts "$dst" "$dst" /etc/mtab)		|| return 1
	[ -n "$d_dev_msg" ]	&& d_dev_msg=\($d_dev_msg\)

	return $es
}




