

# Functions library
# Author: Georgi Kovachev
# Version=1.0.0

# belongs to 'arch' script
# 
# 
# 

do_add ()	# label dir
{
	local keep_IFS i j

	case "$(dir_entry_types "$directory")" in
		0)
			echo "$ME: Directory  $directory  is empty"
			echo "$ME: No action is performed"
			return 0
		;;
		16)
			echo "$ME: Directory  $directory  does not exist"
			es=61
		;;
		8)
			echo "$ME: $directory  is not a directory"
			es=64
		;;
	esac
	verify_label					|| es=$(($? + 64))

	[ $es -eq 0 ]					|| return $es

	echo "$ME: Creating file  $db_dir/$label"

	[ -f "$db_dir/$label"  -a  ! -h "$db_dir/$label" ] && \
		fb_prompt -tp "
    File  $db_dir/$label  exists. Overwrite? [Yes|No] (default No): "

	if [ -z "$n" ]; then
		[ -d "$db_dir" ] || mkdir -p "$db_dir"	|| return 1
		echo -n '' >"$db_dir/$label"		|| return 1
	fi

	keep_IFS=$IFS
	IFS='
' # new line
	for i in $(find "$directory") ; do
		j=$i

		[ -d "$i" ] && j=${j}/
		[ -h "$i" ] && j="$j -->"
		j=${j#"$directory"/}

		[ -n "$j" ]				|| continue
		[ -n "$verb" ] && echo "$j"
		[ -z "$n" ]				|| continue

		echo "$j" >>"$db_dir/$label"		|| ! es=1	|| break
	done
	IFS=$keep_IFS

	return $es
}

do_remove ()	# label
{
	verify_label					|| es=$(($? + 70))
	[ $es -eq 0 ]					|| return $es

	echo "$ME: Removing file  $db_dir/$label"

	if [ -z "$n" ]; then
		rm -f "$db_dir/$label"			|| return 1
	fi
}

do_find ()	# string
{
	local i opts list

	[ "$1" = 'find' ] && shift

	opts='-TH'
	[ -z "$I" ] && opts=${opts}i
	[ -n "$l" ] && list="$db_dir/$l"		|| list="$db_dir/*"

	echo "$ME: Searching in  $list"

	for i in $list ; do
		[ -f "$i"  -a  ! -h "$i" ]		|| continue
		cat "$i" | grep $opts --label="$(basename "$i") " "$*"	|| :
	done
}



