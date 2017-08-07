

# Functions library
# Author: Georgi Kovachev
# Version=1.0.4

# belongs to 'sync-dirs' script
# 
# 
# 

do_syncdirs ()	# dir_list
{
	local keep_IFS suffix

	keep_IFS=$IFS

	# handle files
	suffix=''
	IFS=$new_line
	for file in $f ; do
		[ -n "$file" ]		|| continue
		IFS=$keep_IFS
		create_list "$@"	|| return 0
		sync_files		|| return $?
		IFS=$new_line
	done
	IFS=$keep_IFS

	# handle directories
	suffix='/'
	file=''
	if [ -z "$list" ]; then
		create_list "$@"	|| return 0
		sync_files		|| return $?
	fi
}
































