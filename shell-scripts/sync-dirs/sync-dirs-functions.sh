

# Functions library
# Author: Georgi Kovachev
# Version=1.0.4

# belongs to 'sync-dirs' script
# 
# 
# 

create_list ()	# dir_list
{
	local keep_IFS i j

	keep_IFS=$IFS

	list=''
	IFS=$new_line
	for i in "$@" ; do
		[ -n "$i" ]		|| continue
		target=$(readlnk -P -- "$i/$file")$suffix
		for j in $list ; do
			[ "$j" = "$target" ] && continue 2
		done
		list=$list${target}$new_line
	done
	IFS=$keep_IFS
	[ -n "$list" ]			|| return 1
}

sync_files ()
{
	local es keep_IFS i

	es=0
	keep_IFS=$IFS

	IFS=$new_line
	for i in $list ; do
		IFS=$keep_IFS
		verify_tree "$i" "$target"		|| return $?
		IFS=$new_line
	done
	for i in $list ; do
		IFS=$keep_IFS
		verify_tree "$target" "$i"		|| return $?
		IFS=$new_line
	done

	for i in $list ; do
		IFS=$keep_IFS
		copy_tree "$i" "$target"		|| return $?
		IFS=$new_line
	done
	for i in $list ; do
		IFS=$keep_IFS
		copy_tree "$target" "$i"		|| return $?
		IFS=$new_line
	done

	for i in $list ; do
		IFS=$keep_IFS
		verify_tree_final "$i" "$target"	|| es=$?
		IFS=$new_line
	done
	for i in $list ; do
		IFS=$keep_IFS
		verify_tree_final "$target" "$i"	|| es=$?
		IFS=$new_line
	done
	IFS=$keep_IFS

	return $es
}

copy_tree ()	# src dst
{
	local src dst rs_opts

	rs_outf='--out-format=%i    %f	%L'		# for view only
	rs_opts='-rlpt -u'

	src=$1
	dst=$2

	[ "$src" != "$dst" ]				|| return 0
	echo "$ME: Coping tree    $src  $dst"

	[ -n "$n" ] && rs_opts=${rs_opts}' -n'		# dry run
	[ -n "$v" ] && rs_opts=${rs_opts}' -v'		# verbose
	rsync "$rs_outf" $rs_opts "$src" "$dst"  2>/dev/null	|| :
	[ -n "$v" ] && echo ''				|| :
}

verify_tree_final ()	# src dst
{
	local src dst rs_opts res

	rs_outf='--out-format=%i    %f	%L'		# for view only
	rs_opts='-rlpt  -nu'

	src=$1
	dst=$2

	[ "$src" != "$dst" ]				|| return 0
	echo "$ME: Final verification  $src  $dst"

	res=$(rsync "$rs_outf" $rs_opts "$src" "$dst")	|| return $?	#>/dev/null
	[ -z "$n" ] && [ -n "$res" ] && echo "$res"	|| :
}

verify_tree ()	# src dst
{
	local es src dst rs_optsL1 rs_optsL2 L1 L2 i type name ts ns

	rs_optsL1='--out-format=%i--separator--%n -rlpt  -nu'
	rs_optsL2='--out-format=%i--separator--%n -rlpt  -n'
#	rs_optsL2='--out-format=%i--separator--%f -rlpt  -n  --list-only'	# ls like list

	src=$1
	dst=$2

	[ "$src" != "$dst" ]				|| return 0
	echo "$ME: Veryfing tree  $src  $dst"
	! contains_tree -P "$src" "$dst"		|| return 11

	es=0
	L1=$(rsync $rs_optsL1 "$src" "$dst" 2>/dev/null)	|| :
	L2=$(rsync $rs_optsL2 "$dst" "$src" 2>/dev/null)	|| :

	while read i ; do
		get_type "$i"				|| continue
		ts=$type
		ns=$name

		while read i ; do
			get_type "$i"			|| continue
			if [ "$ns" = "$name" ]; then
				if [ "$ts" != "$type" ]; then
					echo "$ME: Error: ${src%/*}/$ns	is a $ts"
					echo "$ME:        ${dst%/*}/$name	is a $type"
					es=9
				fi
				break
			fi
		done <<- EOL2
			$L2
		EOL2
	done <<- EOL1
		$L1
	EOL1

	return $es
}

get_type ()	# 12 chars
{
	local str a b

	str=$1

	type=''
	name=${str#???????????--separator--}	# 11 chars + --separator--

	case "$str" in
	#	123456789AB--separator--?*)	:	;;
		?f?????????--separator--?*)
			type='file'
		;;
		?d?????????--separator--?*)
			type='directory'
			name=${name%'/'}
		;;
		?L?????????--separator--?*)
			type='link'
		;;
		*)
			a=${str#'cannot delete non-empty directory: '}
			b=${str%$a}
			if [ "$b" = 'cannot delete non-empty directory: ' ]; then
				type='link'
				name=$a
				return 0
			fi
			return 1		# not a valid entry
		;;
	esac
	return 0
}

rsync_version_control ()
{
	local i

	read i <<- EOV
		$(rsync --version)
	EOV

	if [ "$i" != "$rsync_version_str" ]; then
		es=25
		echo "$ME: $es Error: Incomtatible 'rsync' version."
		echo "$ME: $es Error: Must be 3.0.5"
		echo "$ME: $es Error: Fix this and try again."
		return $es
	fi
}

is_local ()	# name
{
	[ "${1%":"*}" = "$1" ]
}

contains_tree  ()	# -P option supplied, patch because of very solow execution
{
	local path dir subdir

	path=${2%'/'}
	dir=${3%'/'}/

	subdir=${dir#"${path%/}/"}
	[ "$subdir" != "$dir" ]
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
$ME  [-nv] dir1 dir2 ... dirn
$ME  [-nvf file1 -f file2 ... -f filen] dir1 dir2 ... dirn
     means dir1/file1 dir2/file1 ... dirn/file1  dir1/file2 dir2/file2 ... dirn/file2 ... 
Options:
    -f         - file
    -n         - dry run rsync option
    -v         - verbose
    --help     - display this help and exit
    --version  - output version information and exit
Examples:
$ME  /usr/local /media/hda1/usr/local
$ME  -f fstab /etc /media/hda1/etc
	" >&2
	[ $es -eq 0 ] && exit "${1:-0}"	|| exit $es
}

init ()
{
# Get command line parameters
	cmd=$1					# command
	case "$#" in
		0|1)
			es=2
		;;
		*)
			cmd='syncdirs'		# mangle command
		;;
	esac
	[ $es -eq 0 ]	|| return $es

#	opts=${a:+'-a'}

# Check if the configuration satisfy the requirements
	must_be_installed

#	cd "$SELFDIR"	|| exit 1		# navigate to self directory for link resolving

	case "$cmd" in
		syncdirs)
			must_be_installed -D rsync
			rsync_version_control			|| es=25
		;;
	esac
	return $es
}























