

# Functions library
# Author: Georgi Kovachev
# Version=1.0.20

# belongs to 'key.sh' script
# 
# 
# 

do_get ()
{
	[ $DEBUG ] && echo -n "$ME: Starting key generator... " >&2

	[ "$1" = 'get' ] && shift
	if [ "$2" = '--no-fallback'  -o  "$2" = '--use-locked-file' ];then
		key_get "$@"
	else
		key_get "$@" || key_get passwd	# fallback to password mode
	fi

	[ $DEBUG ] && echo "Done." >&2 || :
}

do_setup ()
{
	echo -n "$ME: Setting up key $2 ... "
	key_setup "$@"
	echo "Done."
}

do_change ()
{
	[ -n "$2" ]					|| return 0
	echo -n "$ME: Changing key $2 ... " >&2
	if [ $# -eq 2 ]; then
		key_setup "$@" "$2"
	else
		key_setup "$@"
	fi
	echo "Done." >&2
}

do_changekeys ()
{
	"$SELF" change "$dev0"		|| echo '' >&2
	"$SELF" change "$dev1"		|| echo '' >&2
	"$SELF" change "$dev2"		|| echo '' >&2
	"$SELF" change "$dev3"		|| echo '' >&2
	"$SELF" change "$dev4"		|| echo '' >&2
	"$SELF" change "$dev5"		|| echo '' >&2
	"$SELF" change "$dev6"		|| echo '' >&2
	"$SELF" change "$dev7"		|| echo '' >&2
	"$SELF" change "$dev8"		|| echo '' >&2
	"$SELF" change "$dev9"		|| echo '' >&2

	"$SELF" copytree "$path0"	|| :
	"$SELF" copytree "$path1"	|| :
	"$SELF" copytree "$path2"	|| :
	"$SELF" copytree "$path3"	|| :
	"$SELF" copytree "$path4"	|| :
	"$SELF" copytree "$path5"	|| :
	"$SELF" copytree "$path6"	|| :
	"$SELF" copytree "$path7"	|| :
	"$SELF" copytree "$path8"	|| :
	"$SELF" copytree "$path9"	|| :
}

do_copytree ()	# copytree [root_path], e.g. /media/hda2
{
	local dst path

	path=$2

	[ -n "$path" ]					|| return 0
	[ -e "${path}$SELFDIR" ]			|| return 0
	dst=$(readlink -ve -- "${path}$SELFDIR")
	[ -d "$dst"  -a  "$dst" != "$SELFDIR" ]		|| return 0

	echo "$ME: Coping tree to $dst ... "
	remove_dir "${dst}.old"
	remove_dir "${dst}.part"
	cp -pr "$SELFDIR" "$dst.part"
	mv -TS '.old' --  "$dst.part" "$dst"
	sync
	remove_dir "${dst}.old"

	copy_startup_script "${path}/${startup_script}"
	echo "Done."
} >&2

do_block ()
{
	local fn dir

	fn=$(readlink -vf -- "$2")

	if [ -d "$fn" ]; then
		[ -d "${fn}$SELFDIR" ]		|| return 0
	fi

	[ -d "$fn" ] && fn=$(readlink -ve -- "${fn}$SELFDIR")/*		# files

	dir=$(dirname "$fn")
	[ -d "$dir"  -a  -w "$dir" ]
	if contains_tree "$dir" "$SELFDIR" ; then			# self protection
		case "$(basename "$fn")" in
			'' | *'*'* | *'?'*)	return 6	;;
		esac
	fi

	echo -n "$ME: Blocking ${fn} ... "
	crypto_file_remove ${fn}-*[0-9]	# path must not contain white space, TBC
	echo "Done."
}

do_add ()
{
	local km_prefs km_src

	echo "$ME: Adding new key..."

	if ! km_src=$(key_get "$src") ; then
		echo "$ME: Error: Cannot obtain KM from  $src" >&2
		exit 21
	fi
	km_prefs=$(key_get "$prefs") || exit $?

	echo "$(echo "$km_prefs"; echo "$km_src"; echo "$km_src")" | \
		cryptsetup luksAddKey "$dev"
	cryptsetup luksDump "$dev"
}

do_remove ()
{
	local km_prefs km_src

 	echo "$ME: Removing old key..."

	if ! km_src=$(key_get "$src") ; then
		echo "$ME: Error: Cannot obtain KM from  $src" >&2
		exit 22
	fi
	km_prefs=$(key_get "$prefs") || exit $?

	echo "$(echo "$km_src"; echo "$km_prefs")" | \
		cryptsetup luksRemoveKey "$dev"
	cryptsetup luksDump "$dev"
}

do_backup ()
{
	local size

	echo "$ME: Creating LUKS header Backup..."

	size=$(cryptsetup luksDump "$dev" | grep 'Payload offset:' | awk '{print $3}')

	dd if="$dev" of="${bak_file}$(basename "$dev")" count="$size" bs=512
}

do_restore ()
{
	local ans bakf dev_loop fs size uuid_d uuid_f

  	echo "$ME: Restoring LUKS header from Backup..."
	bakf="${bak_file}$(basename "$dev")"
	if ! [ -f "$bakf"  -a  -r "$bakf" ]; then
		echo "$ME: Error: File $bakf does not exist or is not readable." >&2
		es=26
	fi

	fs="$(ls -l --block-size=512  "$bakf" | awk '{print $5}')"
	size=$(cryptsetup luksDump "$dev" | grep 'Payload offset:' | awk '{print $3}')
	if [ "$fs" -ne "$size" ]; then
		echo "$ME: Error: File $bakf" >&2
		echo "$ME: and device $dev LUKS header differs in size." >&2
		es=27
	fi

	dev_loop="$(losetup -f --show "$bakf")"
	uuid_f="$(cryptsetup luksUUID "$dev_loop")" || es=26
	losetup -d "$dev_loop"
	uuid_d="$(cryptsetup luksUUID "$dev")"
	if [ "$uuid_f" != "$uuid_d" ]; then
		echo "$ME: WARNING: File $bakf" >&2
		echo "$ME: and device $dev had difrent UUID in LUKS header." >&2
		echo "$ME: You may be unable to access your data." >&2
		echo ''
		if [ $es -eq 0 ]; then
			echo -n "    OK to proceed? [Yes|No] (default No): "
			if [ "$(read ans; echo "$ans")" != "Yes" ]; then
				echo ''
				echo "$ME: Terminating..."
				echo ''
				sync
				exit 0
			fi
		else
			echo "$ME: ERRORS FOUND" >&2
			es=28
		fi
		echo ''
	fi
	sync
	[ $es -eq 0 ] || return 1

	dd if="$bakf" of="$dev" count="$size" bs=512
}












