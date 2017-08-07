

return
# 


tm_test ()
{
	local ii

	ii=400				# x100

	while [ $ii -gt 0 ]; do
		if [ -n "$*" ]; then
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
			"$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@" ; "$@"
		fi
		ii=$((ii-1))
	done >/dev/null
}

get_type ()	# 12 chars
{
	local str a b

	str=$1

	a=${str#'cannot delete non-empty directory: '}
	b=${str%$a}
	if [ "$b" = 'cannot delete non-empty directory: ' ]; then
		type='link'
		name=$a
		return 0
	fi

	type=''
	name=${str#???????????--separator--}	# 11 chars + --separator--

	case "$str" in
	#	123456789AB--separator--?*)	:	;;
		?L?????????--separator--?*)
			type='link'
		;;
		?f?????????--separator--?*)
			type='file'
		;;
		?d?????????--separator--?*)
			type='directory'
			name=${name%'/'}
		;;
		*)	return 1	;;	# not a valid entry
	esac
}

get_type2 ()	# 12 chars
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

stm tm_test get_type   1L3456789AB--separator--abcd		|| :
stm tm_test get_type2  1L3456789AB--separator--abcd		|| :
stm tm_test get_type   1f3456789AB--separator--abcd		|| :
stm tm_test get_type2  1f3456789AB--separator--abcd		|| :
stm tm_test get_type   1d3456789AB--separator--abcd		|| :
stm tm_test get_type2  1d3456789AB--separator--abcd		|| :
stm tm_test get_type   'cannot delete non-empty directory: 'd1	|| :
stm tm_test get_type2  'cannot delete non-empty directory: 'd1	|| :
stm tm_test get_type   'cannot delete non-empty directory1: 'd1	|| :
stm tm_test get_type2  'cannot delete non-empty directory1: 'd1	|| :
stm tm_test ''	|| :

exit
set -vx


set -vx
get_type   'cannot delete non-empty directory:  d   1'		|| :
get_type2  'cannot delete non-empty directory:  d   1'		|| :
exit

set -vx
get_type   1L3456789AB--separator--abcd		|| :
get_type2  1L3456789AB--separator--abcd		|| :
get_type   1f3456789AB--separator--abcd		|| :
get_type2  1f3456789AB--separator--abcd		|| :
get_type   1d3456789AB--separator--abcd		|| :
get_type2  1d3456789AB--separator--abcd		|| :
get_type   'cannot delete non-empty directory: 'd1	|| :
get_type2  'cannot delete non-empty directory: 'd1	|| :
get_type   'cannot delete non-empty directory1: 'd1	|| :
get_type2  'cannot delete non-empty directory1: 'd1	|| :

exit


is_local  'n  e? z?a  cd'	&& echo 0	|| echo $?
is_local  'n  e: z?a  cd'	&& echo 0	|| echo $?




exit














return









# new versions approvwd






exit

