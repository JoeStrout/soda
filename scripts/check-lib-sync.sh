#!/bin/bash
#
# check-lib-sync.sh — find library modules that exist in more than one of our
# lib directories, and report any whose contents differ.
#
# The canonical copy lives in minimicro-sysdisk; soda and raylib-miniscript
# carry copies of some subset.  For each file name found in two or more of the
# directories, this compares the copies.  It first lists the files that are in
# sync, then, for each file whose copies differ, lists each copy with its
# modification time (marking the newest) and prints a bbdiff command for
# comparing it against the canonical copy.
#
# Usage: check-lib-sync.sh [-i]
#
#   -i  interactive: after reporting each file whose copies differ, ask which
#       version (by its content letter) to keep, and copy it over the other
#       copies of that file.  The default is the newest version; "x" skips.
#
# Exit status is 0 if everything is (now) in sync, 1 if any differences remain.

interactive=0
while getopts "i" opt; do
	case $opt in
		i) interactive=1 ;;
		*) echo "usage: $(basename "$0") [-i]" >&2; exit 2 ;;
	esac
done
shift $((OPTIND - 1))

SVN="${SVN:-$HOME/svnrepo}"
DIRS=(
	"$SVN/minimicro-sysdisk/sys/lib"
	"$SVN/soda/lib"
	"$SVN/raylib-miniscript/assets/lib"
)
LABELS=(sysdisk soda raylib)

for d in "${DIRS[@]}"; do
	[ -d "$d" ] || echo "warning: directory not found: $d" >&2
done

mtime() { stat -f %m "$1"; }
fmtTime() { date -r "$1" "+%Y-%m-%d %H:%M:%S"; }

inSync=0
outOfSync=0
resolved=0
syncList=()
details=$(mktemp "${TMPDIR:-/tmp}/check-lib-sync.XXXXXX")
trap 'rm -f "$details"' EXIT

# In interactive mode, the report for each differing file must appear before
# its prompt, so write it straight to stdout; otherwise collect it in $details
# to print after the in-sync list.
if [ $interactive -eq 1 ]; then
	exec 3>&1
else
	exec 3>"$details"
fi

# Ask which version of $name to keep, and copy it over the other copies.
# Uses the present, group, newest, and nextGroup variables of the main loop.
promptAndCopy() {
	local letters="" choices="" i g src default answer
	for ((g = 1; g <= nextGroup; g++)); do
		letters="$letters$(echo $g | tr 123456789 ABCDEFGHI)"
	done
	for ((g = 0; g < ${#letters}; g++)); do
		choices="$choices(${letters:$g:1}), "
	done
	default=$(echo "${group[$newest]}" | tr 123456789 ABCDEFGHI)
	while true; do
		read -r -p "Keep ${choices}or (x) skip? [$default]: " answer </dev/tty || return
		[ -z "$answer" ] && answer=$default
		answer=$(echo "$answer" | tr a-z A-Z)
		if [ "$answer" = "X" ]; then
			echo "    skipped"
			return
		fi
		if [ ${#answer} -eq 1 ] && [[ "$letters" == *"$answer"* ]]; then break; fi
	done
	g=$(echo "$answer" | tr ABCDEFGHI 123456789)
	for i in "${present[@]}"; do
		[ "${group[$i]}" = "$g" ] && { src="${DIRS[$i]}/$name"; break; }
	done
	for i in "${present[@]}"; do
		[ "${group[$i]}" = "$g" ] && continue
		cp "$src" "${DIRS[$i]}/$name" && echo "    copied $answer -> ${LABELS[$i]}"
	done
	resolved=$((resolved + 1))
}

# Every regular, non-hidden file name in any of the directories.
names=$(for d in "${DIRS[@]}"; do
	[ -d "$d" ] && find "$d" -maxdepth 1 -type f ! -name '.*' -exec basename {} \;
done | sort -u)

for name in $names; do
	# Gather the locations (by index) that have this file.
	present=()
	for i in "${!DIRS[@]}"; do
		[ -f "${DIRS[$i]}/$name" ] && present+=("$i")
	done
	[ ${#present[@]} -lt 2 ] && continue

	first="${DIRS[${present[0]}]}/$name"
	same=1
	for i in "${present[@]:1}"; do
		cmp -s "$first" "${DIRS[$i]}/$name" || { same=0; break; }
	done

	if [ $same -eq 1 ]; then
		inSync=$((inSync + 1))
		where=""
		for i in "${present[@]}"; do where="$where${where:+, }${LABELS[$i]}"; done
		syncList+=("$(printf "    %-20s (%s)" "$name" "$where")")
		continue
	fi

	outOfSync=$((outOfSync + 1))
	echo "DIFFERS   $name"

	newest=-1
	newestTime=0
	for i in "${present[@]}"; do
		t=$(mtime "${DIRS[$i]}/$name")
		if [ "$t" -gt "$newestTime" ]; then newestTime=$t; newest=$i; fi
	done

	# Group copies with identical content, so e.g. "soda = raylib" is visible.
	group=()
	nextGroup=0
	for i in "${present[@]}"; do
		group[$i]=""
		for j in "${present[@]}"; do
			[ "$j" -ge "$i" ] && break
			if cmp -s "${DIRS[$i]}/$name" "${DIRS[$j]}/$name"; then
				group[$i]=${group[$j]}; break
			fi
		done
		if [ -z "${group[$i]}" ]; then
			nextGroup=$((nextGroup + 1))
			group[$i]=$nextGroup
		fi
	done

	base=${present[0]}
	basePath="${DIRS[$base]}/$name"
	for i in "${present[@]}"; do
		path="${DIRS[$i]}/$name"
		note=""
		if [ "${group[$i]}" != "${group[$base]}" ]; then
			if diff -q -w --strip-trailing-cr "$basePath" "$path" >/dev/null; then
				note="  (whitespace only vs ${LABELS[$base]})"
			else
				n=$(diff "$basePath" "$path" | grep -c '^[<>]')
				note="  ($n lines differ vs ${LABELS[$base]})"
			fi
		fi
		[ "$i" -eq "$newest" ] && note="$note  <-- newest"
		printf "    %-8s [%s] %s  %s%s\n" "${LABELS[$i]}" \
			"$(echo "${group[$i]}" | tr 123456789 ABCDEFGHI)" \
			"$(fmtTime "$(mtime "$path")")" "$path" "$note"
	done

	# Suggest a diff of the canonical copy (or the first one present) against
	# the newest copy whose content differs from it.
	other=-1
	otherTime=0
	for i in "${present[@]}"; do
		[ "${group[$i]}" = "${group[$base]}" ] && continue
		t=$(mtime "${DIRS[$i]}/$name")
		if [ $other -lt 0 ] || [ "$t" -gt "$otherTime" ]; then otherTime=$t; other=$i; fi
	done
	echo "    bbdiff \"${DIRS[$base]}/$name\" \"${DIRS[$other]}/$name\""
	[ $interactive -eq 1 ] && promptAndCopy
	echo
done >&3
exec 3>&-

echo "In sync ($inSync):"
for line in "${syncList[@]}"; do echo "$line"; done
echo
[ $interactive -eq 1 ] || cat "$details"
if [ $interactive -eq 1 ]; then
	echo "$inSync in sync, $outOfSync differed, $resolved synced now."
else
	echo "$inSync in sync, $outOfSync differ."
fi
[ $((outOfSync - resolved)) -eq 0 ]
