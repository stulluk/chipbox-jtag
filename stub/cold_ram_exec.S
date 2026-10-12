/* Minimal ARM926 stub: prove code execution from SDRAM @ 0x05000000 (cold).
 * Writes:
 *   0x05001000 = 0xDEAD1337  (ran marker)
 *   0x05001004 = word @ 0x39800400 (flash read via CPU load)
 *   0x05001008 = 0x600D600D  (flash read path completed)
 */
	.syntax unified
	.arch armv5te
	.text
	.global _start

_start:
	ldr	r0, =0x05001000
	ldr	r1, =0xDEAD1337
	str	r1, [r0]

	ldr	r0, =0x39800400
	ldr	r1, [r0]
	ldr	r0, =0x05001004
	str	r1, [r0]

	ldr	r0, =0x05001008
	ldr	r1, =0x600D600D
	str	r1, [r0]

1:	b	1b
