

# Functions library
# Author: Georgi Kovachev
# Version=1.0.6

# belongs to 'secure-device.sudo' script
# 
# 
# 

do_mount ()
{
	local  dir='' es=0

	dir=$(get_mounts "/dev/mapper/$fs" "$mount_point" /etc/mtab)

	if [ -z "$dir" ]; then
		map_file
		/sbin/fsck -n "/dev/mapper/$fs" || { umap_file; return 31; }
		mount $mount_opts "/dev/mapper/$fs" "$mount_point" || return 32
	fi
	sync
}

do_umount ()
{
	local dir='' es=0

	dir=$(get_mounts "/dev/mapper/$fs" '' /etc/mtab)
	while [ "$dir" ]; do
		sync
		umount "$dir" || return 61
		dir=$(get_mounts "/dev/mapper/$fs" '' /etc/mtab)
	done
	umap_file
}

do_create ()
{
	local bs='' count='' es=0

	bs="1${size: -1:1}"	# 1K or 1M
	count="${size%?}"	# e.g. 1234K -> 1234 (remove last symbol)

	sync
	do_umount
	dd if=/dev/urandom of="$mount_file" bs="$bs" count="$count" || es=21
	[ $es -eq 0 ] && chown "${SUDO_USER}:${SUDO_USER}" "$mount_file" || es=22
	[ $es -eq 0 ] && chmod 700 "$mount_file" || es=23

	[ $es -eq 0 ] && map_file || es=$?
	[ $es -eq 0 ] && /sbin/mkfs -t "$fs_type" $fs_opts "/dev/mapper/$fs" || es=24
	umap_file

	[ $es -eq 0 ] && { do_mount || es=$?; }
	if [ $es -eq 0  -a  -z "$chown_dis" ]; then
		chown "${SUDO_USER}:${SUDO_USER}" "$mount_point" || es=25
		chmod 700 "$mount_point" || es=26
	fi
	do_umount

	[ $es -eq 0 ] || rm -f "$mount_file"

	return $es
}

