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
# Usage: check-lib-sync.sh
#
# Exit status is 0 if everything is in sync, 1 if any differences were found.

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
syncList=()
details=$(mktemp "${TMPDIR:-/tmp}/check-lib-sync.XXXXXX")
trap 'rm -f "$details"' EXIT

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
	echo
done > "$details"

echo "In sync ($inSync):"
for line in "${syncList[@]}"; do echo "$line"; done
echo
cat "$details"
echo "$inSync in sync, $outOfSync differ."
[ $outOfSync -eq 0 ]
