#!/bin/bash -e

# Generate key material for disks encryption
# Author: Georgi Kovachev
  Version=1.0.21

# Called by cryptdisks (see /etc/init.d/cryptdisks)
# Uses external devices for key material obtaining
# Fallback to PASSWORD mode
#

PATH=/sbin:/usr/sbin:/bin:/usr/bin
sync
ME=$(basename       -- "$0")			# program name as invoked
SELF=$(readlink -ve -- "$0")			# /absolute/path/program
SELFDIR=$(dirname   "$SELF")			# /absolute/path
SELFNAME=$(basename "$SELF")			# program (true name)


# configuration start -------------------------
config_file=${SELF}.conf			# depends on program location and name
startup_script='/etc/init.d/key-change'		# called at system startup
bak_file="$SELFDIR/key."			# backup prefix

key_setup_size=256K				# entire key size
key_setup_entropy=64				# entropy in bytes
key_encrypt_entropy=32				# entropy in bytes
key_get_prefix='-a r9V8SxAxDFv9xxDUwJw34e get'	# authenticate 'get' command


options='a:nv'					# global options
log_opts='a="$a" n=$n v=$v'			# write options to log file
LOGFILE="/var/log/kassandra/${SELFNAME}.log"	# general log file for kassandra utilities
LOGPREFIX='es=$es'				# log message prefix
LOGSUFFIX='USER=$USER SUDO_USER=$SUDO_USER'	# log message suffix
VERBOSE=2					# 0 - never, 2 - disable, 7 - enable, 9 - max
EXECUTE=7					# 0 - never, 2 - disable, 7 - enable, 9 - max
# configuration end ===========================

# global variables start ----------------------
es=0						# exit status
cmd=$1						# command

src=''						# KM source name
prefs=''					# KM preferences name list, comma separated
dev=''						# device in LUKS format










# global variables end ========================


# load general functions
f=${SELFDIR}/lib/functions.sh
[ -f "$f"  -a  -r "$f" ] && . "$f"	|| \
{ echo "$ME: FATAL ERROR: $f cannot be loaded. Aborting." >&2 ; exit 1 ; }

# load required files
load_libs  lib/encryption-functions.sh
load_libs  ${SELF}-functions.sh  ${SELF}-do-functions.sh

# embeded functions go here

load_libs -f  ${SELF}-dev-functions.sh -- "$@"	# for development purposes

log Load: $(vrb 9 \$@="$@" 2>&1) mcs=$(printf %c ${cmd:-'+'})1		# log load parameters

must_be_root					# root permissions required - exit if not granted
case "$1" in
	--version)		version	;;	# exits with status 0
	--help | --usage)	usage	;;	# exits with status 0
esac

getoptions "$options" "$@"	&& shift $((OPTIND-1))	|| es=2
init "$@"			|| es=$?

log Init: $(vrb 9 cmd=$cmd n=$n v=$v a="$a" \$@="$@" 2>&1) mcs=$(printf %c $cmd)1	# log decoded parameters

feedback --on-load		|| es=$?
[ $es -eq 0 ]			|| exit $es

# move up to action: do what is needed
sync
case "$cmd" in
	setup | change | changekeys | block | copytree | add | remove | backup | restore)
		do_$cmd "$@"
	;;
	*)	# default action: obtain KM
		do_get "$@"
	;;
esac
feedback --on-exit

log Exit: $(vrb 9 cmd=$cmd 2>&1) mcs=$(printf %c $cmd)1		# log exit status

sync
exit $es

