

# Functions library
# Author: Georgi Kovachev
# Version=1.0.15

# belongs to 'bak' script
# 
# 
# 

do_create ()
{
	echo "$ME: Creating Backup... "					>&2
	case "$cmd_types" in
		cb[-f])
			if [ "$cleanup" = 'yes' ]; then
				( "$SELF" -y cleanup "$src" )		|| return $?
			fi
		;;
		cd?)		sleep 2					;;
	esac >&2

	case "$cmd_types" in
		c?f)
			mkdir -pm 700 "$(dirname "$dst")" 2>/dev/null
			encryption_handler
			chmod 444 "$dst"	|| err 22 "mode (chmod) of $dst"
		;;
		*)
			encryption_handler
		;;
	esac
	echo "Done." >&2
}

do_restore ()
{
	local keep_dst dir perm sfx

	keep_dst=$dst
	dir=$(dirname "$dst")

	case "$cmd_types" in
		r[-f]f)
			echo "$ME: Restoring from Backup..."		>&2
			mkdir -pm 700 "$(dirname "$dst")" 2>/dev/null
			encryption_handler
		;;
		r[-f]d)
			[ "$bak_type" != 'system' ] && mkdir -pm 700 "$dst" 2>/dev/null
			perm=$(stat -c %a "$dst")

			if [ "$target_type" = 'home' ]; then
				dst=$(mk_tmp_dir "$dir/home-" .part 8)	|| return 1
			fi

			remove_dst_tree
			echo "$ME: Restoring from Backup..."		>&2
			sleep 2
			encryption_handler

			if [ "$target_type" = 'home' ]; then
				sfx=-$(random_string 16).old
				mv -TS "$sfx" --  "$dst" "$keep_dst"
				sync
				dst=$keep_dst
				rm -fr --one-file-system -- "$dst$sfx"
			fi

		#	chmod "$perm" "$dst"
			if [ "$bak_type" = 'system' ]; then
				do_fstab
				key_db copy
			fi
		;;
		*)
			echo "$ME: Restoring from Backup..."		>&2
			encryption_handler
		;;
	esac
	echo "Done." >&2
}

do_copy ()
{
	if [ "$bak_type" = 'system' ]; then
		remove_dst_tree

		echo "$ME: Copying System tree..."
		sleep 2
		tar -cC "$src" . --one-file-system | tar -xvpC "$dst" --same-owner
		do_fstab
	else
		echo "$ME: Copying Directory..."
		sleep 2
		mkdir -pm 700 "$dst" 2>/dev/null
		tar -cC "$src" . --one-file-system | tar -xvpC "$dst" --same-owner
	fi
	echo "Done." >&2
} >&2

do_fstab ()
{
	local fstab

	echo ''
	echo "$ME: Modifying file  fstab..."

	fstab_handler	|| es=$?

	case "$es" in
		0)
			echo "$ME: File  fstab  adjusted successfully."
		;;
		1)
			echo "$ME: WARNING: Cannot find file  fstab. Adjust manualy."
			echo "$ME: WARNING: Otherwise your system may be  Unbootable!"
		;;
		8|9)
			echo "$ME: WARNING: Invalid  fstab  format. Adjust manualy."
			echo "$ME: WARNING: Otherwise your system may be  Unbootable!"
		;;
		*)
			echo "$ME: WARNING: Cannot cope with  fstab."
			echo "$ME: Adjust manualy."
			echo "$ME: Otherwise your system may be  Unbootable!"
		;;
	esac
	echo "$ME: Used  fstab: $fstab"
	es=0
	return $es
} >&2

do_cleanup ()
{
	local mp

	[ -n "$src" ]		|| return 1

	echo "$ME: Cleaning up source filesystem... "
	if [ -b "$dst" ]; then
		mp=$(mk_tmp_dir "/tmp/${ME}-" .tmp 4)	# get mount point on /tmp
		mount "$dst" "$mp"

		fill_fs "$mp" "$src"

		umount "$mp"
		sync
		! mountpoint -q "$mp"
		rmdir "$mp"				# remove temporary directory
	else
		[ -d "$dst" ]	|| return 1
		fill_fs "$dst" "$src"
	fi
	echo ''
} >&2







