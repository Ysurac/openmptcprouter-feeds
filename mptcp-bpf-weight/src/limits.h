/* SPDX-License-Identifier: GPL-2.0 */
/*
 * BPF-compatible limits.h shim.
 * Replaces libc limits.h under -nostdinc. All values are self-contained
 * so we don't depend on asm-generic/int-limits.h being reachable.
 */
#pragma once

/* Signed integer limits */
#ifndef S8_MAX
#define S8_MAX          ((s8)0x7f)
#endif
#ifndef S16_MAX
#define S16_MAX         ((s16)0x7fff)
#endif
#ifndef S32_MAX
#define S32_MAX         ((s32)0x7fffffff)
#endif
#ifndef S64_MAX
#define S64_MAX         ((s64)0x7fffffffffffffffLL)
#endif

#ifndef S8_MIN
#define S8_MIN          ((s8)(-S8_MAX - 1))
#endif
#ifndef S16_MIN
#define S16_MIN         ((s16)(-S16_MAX - 1))
#endif
#ifndef S32_MIN
#define S32_MIN         ((s32)(-S32_MAX - 1))
#endif
#ifndef S64_MIN
#define S64_MIN         ((s64)(-S64_MAX - 1))
#endif

/* Unsigned integer limits */
#ifndef U8_MAX
#define U8_MAX          ((u8)0xff)
#endif
#ifndef U16_MAX
#define U16_MAX         ((u16)0xffff)
#endif
#ifndef U32_MAX
#define U32_MAX         ((u32)0xffffffffU)
#endif
#ifndef U64_MAX
#define U64_MAX         ((u64)0xffffffffffffffffULL)
#endif

/* Standard C aliases */
#ifndef CHAR_BIT
#define CHAR_BIT        8
#endif
#ifndef INT_MAX
#define INT_MAX         S32_MAX
#endif
#ifndef INT_MIN
#define INT_MIN         S32_MIN
#endif
#ifndef UINT_MAX
#define UINT_MAX        U32_MAX
#endif
#ifndef LONG_MAX
#define LONG_MAX        S64_MAX
#endif
#ifndef LONG_MIN
#define LONG_MIN        S64_MIN
#endif
#ifndef ULONG_MAX
#define ULONG_MAX       U64_MAX
#endif