# Chipbox cold JTAG init — ported from chipbox-orion-full.JLinkScript + ITCM lowlevel_init.
# Requires: source [find mem_helper.tcl] before this file.

set _CHIPBOX_ROOT "/media/WORK/CHIPBOX-REBORN"
set _LOWLEVEL_BLOB "${_CHIPBOX_ROOT}/reference/chipbox_lowlevel_init_v39.bin"

proc chipbox_sdram_misc_ready {} {
	set misc [mrw 0x10110010]
	# lowlevel_init success sets 0x10110010 to 0x30000465 (bit 0x400, not 0x200).
	return [expr {$misc == 0x30000465}]
}

proc chipbox_sdram_probe {} {
	# misc==0x30000465 is necessary but not sufficient — always verify 0x05000000
	# (OpenOCD work-area) is writable; skipping caused slow flash fallback.
	if {[chipbox_sdram_misc_ready]} {
		set pat 0xA5A5A5A5
		if {![catch {mww 0x05000000 $pat} err]} {
			set got [mrw 0x05000000]
			if {$got == $pat} {
				return 1
			}
		}
		return 0
	}
	set misc [mrw 0x10110010]
	if {$misc == 0x30000465} {
		return 0
	}
	if {($misc & 0x400) == 0} {
		return 0
	}
	set pat 0xA5A5A5A5
	if {[catch {mww 0x05000000 $pat} err]} {
		return 0
	}
	set got [mrw 0x05000000]
	return [expr {$got == $pat}]
}

proc chipbox_orion_ddr_init {} {
	echo "Chipbox: Orion DDR init (CSM1201 / v39)"

	set rst [mrh 0x10171200]
	set rst [expr {$rst & ~0x2}]
	mwh 0x10171200 $rst

	mwh 0x10171100 0x084F
	sleep 200

	set rst [mrh 0x10171200]
	set rst [expr {$rst | 0x2}]
	mwh 0x10171200 $rst

	mww 0x10110000 0x97671892
	mww 0x10110004 0x937D0225
	mww 0x10110008 0x08080808
	mww 0x1011000C 0x08080808
	mww 0x10110010 0x30000465
	echo "Chipbox: Orion DDR writes done"
}

proc chipbox_flash_init {} {
	set ce1 0x0B010B01
	set ce2 0x0B010A02

	echo "Chipbox: flash__init() SMC (32M NOR)"

	set rd [mrw 0x10100000]
	set iobits [expr {($rd >> 24) & 0x1}]
	mww 0x10100000 [expr {($rd & ~0xFF) | 0x0C}]
	mww 0x10100004 $ce1
	mww 0x10100008 $ce2

	set rd [mrw 0x1010000C]
	mww 0x1010000C [expr {($rd & ~0xFF) | 0x0C}]
	mww 0x10100010 $ce1
	mww 0x10100014 $ce2
	set rd [mrw 0x1010000C]
	mww 0x1010000C [expr {($rd & ~0x01000000) | ($iobits << 24)}]

	set rd [mrw 0x10100018]
	mww 0x10100018 [expr {($rd & ~0xFF) | 0x0C}]
	mww 0x1010001C $ce1
	mww 0x10100020 $ce2
	set rd [mrw 0x10100018]
	mww 0x10100018 [expr {($rd & ~0x01000000) | ($iobits << 24)}]

	set rd [mrw 0x10100024]
	mww 0x10100024 [expr {($rd & ~0xFF) | 0x0C}]
	mww 0x10100028 $ce1
	mww 0x1010002C $ce2
	set rd [mrw 0x10100024]
	mww 0x10100024 [expr {($rd & ~0x01000000) | ($iobits << 24)}]

	mww 0x10100038 1

	set val [mrw 0x10100000]
	mww 0x1010000C $val
	mww 0x10100018 $val
	mww 0x10100024 $val

	set val [mrw 0x10100004]
	mww 0x10100010 $val
	mww 0x1010001C $val
	mww 0x10100028 $val

	set val [mrw 0x10100008]
	mww 0x10100014 $val
	mww 0x10100020 $val
	mww 0x1010002C $val

	echo "Chipbox: flash__init done"
}

proc chipbox_itcm_lowlevel_init {target} {
	global _LOWLEVEL_BLOB

	if {![file exists $_LOWLEVEL_BLOB]} {
		echo "Chipbox: missing $_LOWLEVEL_BLOB"
		return -1
	}

	echo "Chipbox: ITCM + v39 lowlevel_init blob"
	# Match J-Link: wcp15ex ITCM/DTCM enable before ITCM writes.
	arm mcr 15 0 9 1 1 0x20000019
	arm mcr 15 0 9 1 0 0x20008019

	load_image $_LOWLEVEL_BLOB 0x20000000
	mww 0x20001000 0xEAFFFFFE
	reg lr 0x20001000
	reg pc 0x20000000
	resume
	sleep 300
	catch {halt 5000}
	poll off
	echo "Chipbox: lowlevel_init returned, misc=[format 0x%x [mrw 0x10110010]]"
	return 0
}

proc chipbox_cold_init {target} {
	if {[chipbox_sdram_probe]} {
		echo "Chipbox: SDRAM up — ITCM refresh for OpenOCD work-area"
		chipbox_itcm_lowlevel_init $target
		chipbox_flash_init
		if {![chipbox_sdram_probe]} {
			echo "Chipbox: SDRAM lost after ITCM refresh"
			return -1
		}
		echo "Chipbox: cold init OK (ITCM refresh)"
		return 0
	}

	set misc [mrw 0x10110010]
	if {($misc & 0x400) != 0} {
		echo "Chipbox: misc bit set but SDRAM probe failed — re-init"
	}

	chipbox_orion_ddr_init
	if {![chipbox_sdram_probe]} {
		echo "Chipbox: register DDR insufficient — ITCM path"
		chipbox_itcm_lowlevel_init $target
	}

	if {![chipbox_sdram_probe]} {
		echo "Chipbox: SDRAM init FAILED"
		return -1
	}

	chipbox_flash_init
	if {![chipbox_sdram_probe]} {
		echo "Chipbox: SDRAM lost after flash_init"
		return -1
	}

	echo "Chipbox: cold init OK"
	return 0
}


proc chipbox_flash_erase_full {base size} {
	flash probe 0
	echo "CHIPBOX_PROGRESS erase start base=${base} size=${size}"
	flash erase_address $base $size
	echo "CHIPBOX_PROGRESS erase done"
}

proc chipbox_dump_read {outfile addr size} {
	echo "CHIPBOX_PROGRESS dump_image addr=${addr} size=${size}"
	dump_image $outfile $addr $size
	echo "CHIPBOX_PROGRESS dump_image done addr=${addr}"
}

proc chipbox_dump_read_chunks {outdir count chunk_size base} {
	set total [expr {$count * $chunk_size}]
	for {set i 0} {$i < $count} {incr i} {
		set off [expr {$i * $chunk_size}]
		set addr [format 0x%x [expr {$base + $off}]]
		set path [format "%s/chunk_%02d.bin" $outdir $i]
		set done [expr {($i + 1) * $chunk_size}]
		set pct [format %.1f [expr {100.0 * $done / double($total)}]]
		echo "CHIPBOX_PROGRESS chunk_start idx=[expr {$i + 1}] total=${count} addr=${addr} bytes=${done}/${total} pct=${pct}%"
		dump_image $path $addr [format 0x%x $chunk_size]
		echo "CHIPBOX_PROGRESS chunk_done idx=[expr {$i + 1}] total=${count} file=${path} bytes=${done}/${total} pct=${pct}%"
	}
	echo "CHIPBOX_PROGRESS dump_all_done bytes=${total}"
}

# Legacy alias
proc chipbox_flash_read_chunks {outdir count {chunk_size 0x8000} {base 0x38000000}} {
	chipbox_dump_read_chunks $outdir $count $chunk_size $base
}

proc chipbox_flash_write_chunks {indir count {chunk_size 0x200000}} {
	flash probe 0
	set total_bytes [expr {$count * $chunk_size}]
	for {set i 0} {$i < $count} {incr i} {
		set off [expr {$i * $chunk_size}]
		set offhex [format 0x%x $off]
		set path [format "%s/chunk_%02d.bin" $indir $i]
		set idx [expr {$i + 1}]
		set done_bytes [expr {$idx * $chunk_size}]
		set pct [format %.1f [expr {100.0 * $done_bytes / double($total_bytes)}]]
		echo "CHIPBOX_PROGRESS write chunk_start idx=${idx} total=${count} offset=${offhex} bytes=${done_bytes}/${total_bytes} pct=${pct}%"
		flash write_bank 0 $path $offhex
		echo "CHIPBOX_PROGRESS write chunk_done idx=${idx} total=${count} offset=${offhex} bytes=${done_bytes}/${total_bytes} pct=${pct}%"
	}
	echo "CHIPBOX_PROGRESS write all_done count=${count} bytes=${total_bytes}"
}

# Legacy name used by older scripts.
proc chipbox_orion_init {} {
	global _TARGETNAME
	chipbox_cold_init $_TARGETNAME
}

proc chipbox_cold_connect {} {
	# reset halt triggers SYSCOMP timeouts on this clone; halt + poll off is reliable.
	halt
	poll off
	sleep 50
}
