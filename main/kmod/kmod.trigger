#!/bin/sh

for i in "$@"; do
	if [ -e "$i"/modules.order ]; then
		/sbin/depmod "${i#*/lib/modules/}"
	elif [ -d "$i" ]; then
		#clean up on uninstall
		rm -f "$i"/modules.alias \
			"$i"/modules.builtin.alias.bin \
			"$i"/modules.dep \
			"$i"/modules.devname \
			"$i"/modules.symbols \
			"$i"/modules.alias.bin \
			"$i"/modules.builtin.bin \
			"$i"/modules.dep.bin \
			"$i"/modules.softdep \
			"$i"/modules.symbols.bin \
			"$i"/modules.weakdep
		rmdir "$i" 2>/dev/null || :
	fi
done

