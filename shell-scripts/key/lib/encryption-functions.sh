
# Functions library
# Author: Georgi Kovachev
# Version=1.0.9


# Encrypt/decrypt with a symmetric cipher using a passphrase
# Input:  $1 - gpg option -c or -d
#         $2 - source (stdin, device or regular file)
#         $3 - destination (stdout, device or regular file)
#         $4 - passphrase
# Output: encrypted/decrypted stream if stdout selected, none otherwise
# Exit status: 0 if success, greater than 0 if error
gpg_encryption ()	# -c | -d source destination passphrase
{
	local opts_all opts_encr opts_decr opts cmd src dst pf pfd9

	opts_all='--no-options --no-use-agent --no-default-keyring --keyring /dev/null'
	opts_encr="-c $opts_all --no-random-seed-file --cipher-algo AES256 -z1"
	opts_decr="-d $opts_all --secret-keyring /dev/null --yes"

	cmd="$1"				# gpg option (-c encrypt, -d decrypt)
	src=${2:-'-'}				# stdin
	dst=${3:-'-'}				# stdout
	pf=$(km_shrink "$4" 640)		|| return 1

	shift 4
	pfd9=${pf:+'--passphrase-fd 9'}		# passphrase on file descriptor 9

	case "$cmd" in
		'-c')	opts=$opts_encr	;;	# encrypt options
		'-d')	opts=$opts_decr	;;	# decrypt options
		*)	return 1	;;
	esac

	gpg  $opts "$@" $pfd9  -o "$dst"  "$src"  9<<- EoF
		$pf
	EoF
}


# Remove file(s) cryptographicaly strong
# Input:  $1 - overwrite -n times, e.g. -n 1000 | -n1000 (optional)
#         $2 - file list
#         all arguments must be file(s) or non existent, error orherwise
# Output: None
# Exit status: 0 if success, greater than 0 if error
crypto_file_remove ()	# [-n 1000 | -n1000] file list
{
	local i n

	[ x${1%${1#'-n'}} = 'x-n' ]	&& n=${1#'-n'}	&& i=1
	[ "$1" = '-n' ]			&& n=$2		&& i=2
	[ "$1" = '--' ]			&& n=100	&& i=1
	n=$(str2int "$n")		&& shift $i	|| n=100

	sync
	for i in "$@" ; do
		[ -f "$i"  -o  ! -e "$i" ]	|| return 1
	done

	for i in "$@" ; do
		if [ -f "$i" ]; then
			shred -un $n -- "$i"	|| return 2
			sync
		fi
	done
}


# Find encryption key manager script
# Input:  None
# Output: absolute path to encryption key manager script file
# Exit status: 0 if success, greater than 0 if error
find_key_script ()
{
	local crypttab key_script name f1 f2 f3 f4 rest

	crypttab='/etc/crypttab'
	[ -f "$crypttab"  -a  -r "$crypttab" ]			|| return 2

	while read f1 f2 f3 f4 rest ; do
		[ -n "$f1"  -a  "${f1#'#'}" = "$f1" ]		|| continue
		key_script=${f4#*keyscript=}
		[ "$key_script" != "$f4" ]			|| continue
		name=${f4%$key_script}
		[ "${name##*,}" = 'keyscript=' ]		|| continue
		key_script=${key_script%%,*}

		[ -n "$key_script"  -a  -f "$key_script"  -a  \
		  -r "$key_script"  -a  -x "$key_script" ] && \
			echo -n "$key_script"	&& return 0
	done < "$crypttab"
	return 1
}


# Generate random number based on /dev/random and /dev/urandom
# Input:  $1 - block size in bytes
#         $2 - count bytes from /dev/random
# Output: random number, base64 encoded
# Exit status: 0 if success, greater than 0 if error
km_generate ()
{
	local i km ovrb rndb rndbK size sizeK

	size=$1
	rndb=$2

	[ x${size#${size%?}} = 'xK' ] && size=${size%?} && sizeK=1 || sizeK=0
	size=$(str2int "$size")			|| return 1	# desired size
	[ $sizeK -eq 1 ] && size=$((size * 1024))

	[ x${rndb#${rndb%?}} = 'xK' ] && rndb=${rndb%?} && rndbK=1 || rndbK=0
	rndb=$(str2int "$rndb")			|| return 2	# desired random bytes
	[ $rndbK -eq 1 ] && rndb=$((rndb * 1024))

	[ $size -ge 0  -a  $rndb -ge 0 ]	|| return 3
	[ $rndb -le $size ]			|| return 4

	ovrb=$((size - rndb))					# over bytes

	i=0
	while [ $i -lt $rndb ]; do
		dd if=/dev/random  bs=1  count=1		2>/dev/null
		i=$((i+1))
	done
	[ $ovrb -ne 0 ] && dd if=/dev/urandom bs=$ovrb count=1	2>/dev/null
}


# AF split/join for weak key material
# Input:  $1 - command, encode or decode
#         $2 - key material
#         $3 - minimum output size, respected by "encode" only
# Output: key material, encoded or decoded
#         after encoging output size is always larger than $3
# Exit status: 0 if success, greater than 0 if error
km_split ()
{
	local cmd i km size sizeK

	cmd=$1
	km=$2
	size=${3:-'-1'}

	[ x${size#${size%?}} = 'xK' ] && size=${size%?} && sizeK=1 || sizeK=0
	size=$(str2int "$size")					|| return 1	# desired size
	[ $sizeK -eq 1 ] && size=$((size * 1024))

	case "$cmd" in
		encode)
			i=100
			km=c$km
			while [ ${#km} -lt "$size" ]; do
				km=$(echo -n "$km" | base64 -w0)
				i=$((i+1))
			done
			echo -n "${i}$km"
		;;
		decode)
	#		i=$(str2int "$(echo -n "$km" | dd bs=3 count=1 2>/dev/null)")	|| return 2
			i=$(str2int "$(printf %.3s "$km")")	|| return 2
			km=${km#???}
			while [ $i -gt 100 ]; do
				km=$(echo -n "$km" | base64 -d)	|| return 3
				i=$((i-1))
			done
			[ -n "$km" ] && echo -n "${km#?}" 	|| return 4
		;;
		*)	return 1				;;
	esac
}


# Shrink for large key material
# Input:  $1 - key material
#         $2 - output size
# Output: key material, shrinked to desired size if larger, no change otherwise
# Exit status: 0 if success, greater than 0 if error
km_shrink ()
{
	local km size sha512size buff hash hash_offs hash_size

	km=$1						# key material
	size=$(str2int "$2") || return 1		# desired size
	sha512size=128					# bytes ASCII

	[ "${#km}" -le "$size" ] && echo -n "$km" && return 0	# OK, km too small, fits
	[ "$size" -lt "$sha512size" ] && return 2	# error, size too small, cannot fit

	hash_offs=$((size - sha512size))
	hash_size=$((${#km} - hash_offs))

	buff=$(echo -n "$km" | dd ibs=1 obs=64K skip=0 count="$hash_offs" 2>/dev/null)
	hash=$(echo -n "$km" | dd ibs=1 obs=64K skip="$hash_offs" 2>/dev/null | sha512sum)
	hash=${hash%???}
	echo -n "$buff$hash"
}


# Read password from stdin
# Input:  $1 - times repeat, 1..9, default 1
# Output: password, plain
# Exit status: 0 if success, greater than 0 if error
km_get_passwd ()	{ km_get_tty "$@"	; }
km_get_tty ()
{
	local rpt i flag km km2

	case "$1" in				# times repeat
		[1-9])	rpt=$1		;;
		*)	rpt=1		;;
	esac

	i=0
	stty -echo
	while [ $i -lt $rpt ]; do
		flag=1
		if [ $i -eq 0 ]; then
			read -p "Enter Password: " km >&2	|| break
			km2=$km
		else
			read -p "Repeat Password: " km2 >&2	|| break
		fi
		echo ''  >&2
		flag=0

		if [ "x$km" != "x$km2" ]; then
			echo "$ME: Not matched. Please try again." >&2
			i=-1
		fi
		i=$((i+1))
	done
	stty echo
	[ $flag -eq 0 ] || echo "$ME: User canceled operation. Password not accepted." >&2
	[ $i -eq $rpt  -a  "x$km" = "x$km2" ] && echo -n "$km" || return 1
}














