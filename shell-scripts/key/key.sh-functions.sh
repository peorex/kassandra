

# Functions library
# Author: Georgi Kovachev
# Version=1.0.21

# belongs to 'key.sh' script
# 
# 
# 

key_setup ()
{
	local fid km km_src

	shift
	key_get_params "$@"
	km_src=$2

	sleep 1
	if [ "$cmd" = 'setup'  -a  "$km_src" = '--generate' ]; then
		km=$(km_generate  $key_setup_size  $key_setup_entropy | base64 -w0)
		[ -n "$km" ]
	else
		km=$("$SELF" $key_get_prefix "$km_src" '--no-fallback')
	fi

	if [ "$cmd" = 'setup' ]; then
		crypto_file_remove "${fn}"-*[0-9]
		key_dev clear
	else
		while fid=$(key_get_id "$fn" '--use-locked-file') ; do
			crypto_file_remove "${fn}-${fid}"
		done
	fi
	rm -f "${fn}"-*.lock

	touch "${fn}-${nxt_id}.lock"
	echo -n "$km" | key_dev encrypt "${fn}-${nxt_id}" "$key_encrypt_entropy"
	chmod 600 "${fn}-${nxt_id}"
	[ "$km" = "$("$SELF" $key_get_prefix "$fn" '--use-locked-file')" ]

	if [ $nxt_id -ne $id ];then
		mv "${fn}-${nxt_id}.lock" "${fn}-${id}.lock"
		crypto_file_remove "${fn}-${id}"
	fi
	rm -f "${fn}"-*.lock
}

remove_dir ()
{
	local dir

	dir=$1

	[ -n "$dir" ]					|| return 1
	if [ -d "$dir" ]; then
		"$SELF" block "$dir/*"			|| return 1
		rm -fr --one-file-system -- "$dir"	|| return 1
		sync
	fi
	[ ! -e "$dir" ]
}

copy_startup_script ()	# startup/script/file
{
	local as dir script opts

	opts='--preserve=timestamps,mode --remove-destination'

	script=$(readlink -vf -- "$1")
	as=${SELFDIR}/$(basename "$script")
	dir=$(dirname "$script")
	[ -d "$dir"  -a  "$dir" != "$SELFDIR" ]
	[ -f "$script"  -o  ! -e "$script" ]

	[ "$script" -ot "$as"  -o  "$script" -nt "$as" ] && \
		cp $opts "$as" "$script"	|| :
}

key_get_id ()
{
	local fn ul i id cid

	fn=$1
	ul=$2

	id=-1
	for i in "$fn"-* ; do
		[ -f "$i" ]			|| continue
		[ "$i" = "${i%.lock}" ]		|| continue
		cid=${i#${fn}-}

		case "$cid" in
			[1-9][0-9]|[1-9][0-9][0-9])	:	;;
			[0-9]|[1-9][0-9][0-9][0-9])	:	;;
			*)			continue	;;
		esac

		[ "$ul" != '--use-locked-file'  -o     -e  "${i}.lock" ] && \
		[ "$ul"  = '--use-locked-file'  -o  !  -e  "${i}.lock" ] && \
			[ $cid -gt $id ] && id=$cid
	done

	[ $id -ge 0 ] && echo -n "$id"
}

key_get_params ()
{
	local bfn

	fn=$(readlnk -- "$1")			|| return 1
	shift
	bfn=$(basename "$fn")

	eval in=\$${bfn}_in
	eval bs=\$${bfn}_bs
	eval offs=\$${bfn}_offs
	eval size=\$${bfn}_size
	eval count=\$${bfn}_count
	eval sid_sfx=\$${bfn}_sid_sfx
	eval sec_sfx=\$${bfn}_sec_sfx

	[ -n "$in" ]				|| return 1

	id=0
	nxt_id=0
	if [ "$cmd" != 'setup' ]; then
		id=$(key_get_id "$fn" "$@")	|| return 1
		[ $((id + 1)) -lt $((size / count)) ] && nxt_id=$((id+1))
	fi

	[ $((id + 1)) -le $((size / count)) ]	|| return 1
	skip_offs=$((offs + id*count))
	seek_offs=$((offs + nxt_id*count))
}

key_pw_sfx_usb ()
{
	local bus_dev id list salt1 salt2 sfx f1 f2 f3 f4 rest

	salt1='CWweiROcHrI1nPgWT6uCCdRPJjoMX7hPfaI7M18vrF57Se8m'	# 48
	salt2='qYv3v2R7sy6M49WPlNnGikKou5nmv3cQKqvdi0cO208VpBwx'	# 48

	[ -n "$sid_sfx" ] && list=$(lsusb)		|| return 1

	while read f1 f2 f3 f4 rest ; do
		bus_dev=${f2}:${f4%?}

		case "$bus_dev" in
			[0-9][0-9][0-9]:[0-9][0-9][0-9])	:	;;
			*)	return 1				;;
		esac

		sfx=$(lsusb -vs "$bus_dev" 2>/dev/null | \
		awk '
		{
			if ($1 == "idVendor")	idV = $2
			if ($1 == "idProduct")	idP = $2
			if ($1 == "iSerial")	iSe = $3
		}
		END	{
				OFS = ORS = ""
				if (idV && idP && iSe)
					print	idV, idP, iSe
			}
		' )					|| return 1
		id=$(echo -n "$salt1$sfx$salt2" | sha512sum)
		[ x${id%${id#????}} = "x$sid_sfx" ]	|| continue
		[ -n "$sfx" ] && echo -n "$sfx"		&& return 0
	done <<- EOL
		$list
	EOL
	return 1
}

key_pw_sfx_fd ()
{
	[ -n "$sec_sfx" ]				|| return 2
	sfx=$(dd if="$in" bs="$bs" skip="$sec_sfx" count=1 2>/dev/null | base64 -w0)
	[ -n "$sfx" ] && echo -n "$sfx"			|| return 2
}

key_pw_sfx ()
{
	key_pw_sfx_usb	|| \
	key_pw_sfx_fd
}

key_dev ()
{
	local cmd entropy pw km fn

	set -e
	cmd=$1
	fn=$2
	entropy=$3

	sync
	case "$cmd" in
		encrypt)
			pw=$(km_generate  $((bs * count))  $entropy | base64 -w0)
			echo -n "$pw" | base64 -d | dd of="$in" bs="$bs" seek="$seek_offs" count="$count" 2>/dev/null
			pw=$pw$(key_pw_sfx)
			km=$(km_split encode "$(dd 2>/dev/null)" "$key_setup_size")
			echo -n "$km" | gpg_encryption -c - "$fn"  "$pw" --batch -z0 --yes	2>/dev/null
		;;
		decrypt)
			pw=$(dd if="$in" bs="$bs" skip="$skip_offs" count="$count" 2>/dev/null | base64 -w0)
			pw=$pw$(key_pw_sfx)
			km=$(gpg_encryption -d "$fn" -  "$pw" --batch		2>/dev/null)
			km_split decode "$km"
		;;
		clear)
			dd if=/dev/urandom of="$in" bs="$bs" seek="$offs" count="$size" 	2>/dev/null
		;;
		*)	return 1	;;
	esac
	sync
}

key_get_secure_device ()		# /path/to/secure_device/file
{
	local km in_file

	in_file=$(readlink -ve -- "$1" 2>/dev/null)	|| return 1

	# must be a regular file with read permission granted
	if [ -f "$in_file"  -a  -r "$in_file" ]; then
		cat "$in_file" | sed -n '/Password:[ \t]\{1,\}/p' | awk '{print $2}'
	fi
}

key_get_prefix_value ()
{
	local a

	getoptions a: $key_get_prefix && echo -n "$a"	|| :
}

key_is_enabled_get ()
{
	local es Type

	[ $# -ne 0 ]		|| return 1

	es='U'
	Type=0

	log KIEG: $(vrb 9 cmd=$cmd n=$n v=$v a="$a" params="$@" 2>&1) mcs=$(printf %c $cmd)1
	exc 8 log KIEG: exc 8 : "$(printenv)"

	[ "$RUNLEVEL" = 'S' ]			&& Type=$((Type + 1))
	[ ! -e "/dev/mapper/$encr_dev" ]	&& Type=$((Type + 2))
	[ "$cmd" = 'get' ]			&& Type=$((Type + 4))
	[ "$a" = "$(key_get_prefix_value)" ]	&& Type=$((Type + 8))

	if [ $Type -eq 3 ]; then
		log KIEG: Type=$Type
		return 0
	fi

	if [ $Type -eq 12 ]; then
		log KIEG: Type='C'
		return 0
	fi

	log KIEG: Failed to enable ---- Type=$Type "$(printenv)"
	return 1
} >&2

# handler

key_get ()	# km source preferences list, comma delimited (fd,usb,passwd1,passwd2,passwd)
{
	local prefs pref keep_IFS km es

	[ $# -ne 0 ] && key_is_enabled_get "$@"					|| return 1

	prefs=$1
	shift

	es=1
	keep_IFS=$IFS
	IFS=','
	for pref in $prefs; do
		IFS=$keep_IFS
		case "$(basename "$pref")" in
			usb1t | usb1 | usb1p | usb1r | \
			 fd1t |  fd1 |  fd1p |  fd1r )

				key_get_params "$pref" "$@"			|| continue
				km=$(key_dev decrypt "${fn}-$id" "$@")		&& es=0
			;;
			secure_device)
				km=$(key_get_$pref "$@") || km=''
				[ -n "$km" ] && es=0
			;;
			tty*|passwd*)			# $1 - times repeat (1..9)
				km=$(km_get_tty  ${pref#${pref%?}} "$@")	&& es=0
			;;
		esac
		IFS=','
		[ $es -eq 0 ] && break
	done
	IFS=$keep_IFS

	[ $es -eq 0 ] && echo -n "$km" || return $es
}

feedback ()
{
	return 0
} >&2

usage ()
{
	echo "
Usage:
$ME  add       pswd_src  old,pswd,list  device  # add password to device
$ME  remove    pswd_src  old,pswd,list  device  # remove password from device
$ME  backup    device                           # create device LUKS header backup
$ME  restore   device                           # restore device LUKS header from backup
$ME  pswd,src,list                              # obtain key material from preferences lisl
$ME  setup     pswd_src  pswd,list              # set external device password
$ME  change    pswd_src  [pswd,list]            # change external device password
$ME  block     pswd_src                         # block external device password
$ME  copytree  [root_path]                      # copy all files to another location
Options:
    --help     - display this help and exit
    --version  - output version information and exit
Examples:
$ME  add       usb     floppy,bluetooth  /dev/sda1
$ME  add       passwd  floppy,bluetooth  /dev/sda1
$ME  remove    floppy  bluetooth         /dev/sda1
$ME  backup    /dev/sda1
$ME  restore   /dev/sda1
$ME  usb,floppy,bluetooth
$ME  setup     fd2  --generate
$ME  setup     fd2  usb
$ME  change    fd2  usb
$ME  block     fd2
$ME  copytree  /media/hda2                       # means: /media/hda2/path/to/program/tree/
	" >&2
	[ $es -eq 0 ] && exit "${1:-0}"	|| exit $es
}

init ()
{
# Get command line parameters
	cmd=$1					# command
	case "$#" in
		0)
			cmd='changekeys'	# mangle command
		;;
		1)
			prefs=$1		# source of existing KM
		;;
		2)
			dev=$2			# device (backup | restore)
		;;
		4)
			src=$2			# source of KM to be added/removed (add | remove)
			prefs=$3		# source of existing KM
			dev=$4			# device
		;;
		3)
			:			# setup | change
		;;
		*)
			es=2
		;;
	esac
	[ $es -eq 0 ]	|| return $es

#	opts=${a:+'-a'}

# Check if the configuration satisfy the requirements
	must_be_installed -s cryptsetup lsusb

	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving

	# load config file(s)
	load_libs  "$config_file"				|| exit 3
	copy_startup_script "$startup_script"	# optimized copy in /etc/init.d/

	case "$cmd" in
		add | remove | backup | restore)
			case "$cmd" in
				add | remove)
					[ -n "$src" ]   || return 11
					[ -n "$prefs" ] || return 12
				;;
			esac

			[ -n "$dev" ] || return 13
			[ -e "$dev" ] || return 14
			[ -b "$dev" ] || return 15
			if ! cryptsetup isLuks "$dev" ; then
				echo "$ME: Error: Device $dev is not LUKS." >&2
				return 16
			fi
		;;
	esac
	return $es
}



























