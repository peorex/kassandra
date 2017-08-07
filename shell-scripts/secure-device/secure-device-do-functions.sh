

# Functions library
# Author: Georgi Kovachev
# Version=1.0.6

# belongs to 'secure-device.sudo' script
# 
# 
# 

do_create ()
{
	echo "$ME: Creating Security Device Filesystem..."
	sleep 1

	if [ ! -d "$mount_point" ]; then
		mkdir -pm 700 "$mount_point" &>/dev/null	|| return $?
	fi

	(
		sudo "${SELF}.sudo" create "$mount_file" "$mount_point" \
			"$fs_type" "$fs_opts" "$size" &>/dev/null
	)	|| es=$?

	[ $es -eq 0 ] && echo 'Done.'
	return $es
}

do_mount ()
{
	echo "$ME: Mounting Security Device Filesystem..."

	(
		sudo "${SELF}.sudo" mount "$mount_file" "$mount_point" \
			"$fs_type" 5 6 &>/dev/null
	)	|| es=$?

	[ $es -eq 0 ] && echo 'Done.'
	sleep 2
	return $es
}

do_umount ()
{
	echo "$ME: Unmounting Security Device Filesystem..."

	(
		sudo "${SELF}.sudo" umount "$mount_file" 3 4 5 6 &>/dev/null
	)	|| es=$?

	[ $es -eq 0 ] && echo 'Done.'
	sleep 2
	return $es
}

do_use ()
{
 	echo "$ME: Preparing Security Device Filesystem..."

	do_mount	|| es=$?
	[ $es -eq 0  -o  $es -eq 10 ] || return $es	# may be already mounted
	/etc/alternatives/x-www-browser "${mount_point}/index.html"
	do_umount	|| es=$?

	[ $es -eq 0 ] && echo 'Done. Security Device Unmounted.'
	sleep 2
	return $es
}

