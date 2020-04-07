#ifndef DUCK_X86_64_H
#define DUCK_X86_64_H

#include <stdint.h>
#include <x86intrin.h>

namespace x86_64 {
	static inline void outb(int port, uint8_t data) {
		__asm__ volatile ("outb %0, %w1" : : "a" (data), "d" (port));
	}
	
	static inline uint8_t inb(int port) {
		uint8_t data;
		__asm__ volatile ("inb %w1, %0" : "=a" (data) : "d" (port));
		return data;
	}
	
	static inline void outl(int port, uint32_t data) {
		__asm__ volatile ("outl %0, %w1" : : "a" (data), "d" (port));
	}
	
	static inline uint32_t inl(int port) {
		uint32_t data;
		__asm__ volatile ("inl %w1, %0" : "=a" (data) : "d" (port));
		return data;
	}
	
	static inline void lidt(void *p) {
		__asm__ volatile ("lidt (%0)" : : "r" (p));
	}
	
	static inline void lgdt(void *p) {
		__asm__ volatile ("lgdt (%0)" : : "r" (p));
	}
	
	static inline void ltr(uint16_t sel) {
		__asm__ volatile ("ltr %0" : : "r" (sel));
	}
	
	template <typename T>
	static inline void lcr3(T p) {
		__asm__ volatile ("movq %0, %%cr3" : : "r" ((uint64_t) p));
	}
	
	static inline uint64_t rcr3() {
		uint64_t ret;
		__asm__ volatile ("movq %%cr3, %0" : "=r" (ret));
		return ret;
	}
	
	static inline void sti() {
		__asm__ volatile ("sti");
	}
	
	static inline void cli() {
		__asm__ volatile ("cli");
	}
	
	static inline void hlt() {
		__asm__ volatile ("hlt");
	}
	
	static inline uint64_t rdtsc() {
		return __rdtsc();
	}
	
	static inline void cpuid(uint32_t info,
		uint32_t *eaxp, uint32_t *ebxp, uint32_t *ecxp, uint32_t *edxp) {
		uint32_t eax, ebx, ecx, edx;
		asm volatile("cpuid"
			: "=a" (eax), "=b" (ebx), "=c" (ecx), "=d" (edx)
			: "a" (info));
		if (eaxp) *eaxp = eax;
		if (ebxp) *ebxp = ebx;
		if (ecxp) *ecxp = ecx;
		if (edxp) *edxp = edx;
	}
	
	static inline uint64_t read_rflags() {
		uint64_t rflags;
		__asm__ volatile ("pushfq; popq %0" : "=r" (rflags));
		return rflags;
	}
	
	static inline void set_fs(uint64_t p) {
		__asm__ volatile ("wrfsbase %0" : : "r" (p));
	}
	
	static inline uint64_t get_fs() {
		uint64_t ret;
		__asm__ volatile ("rdfsbase %0" : "=r" (ret));
		return ret;
	}
	
	static inline uint64_t rdmsr(uint32_t msr) {
		uint32_t hi, lo;
		__asm__ volatile ("rdmsr" : "=a" (lo), "=d" (hi) : "c" (msr));
		return ((uint64_t) hi << 32) | lo;
	}
	
	static inline void wrmsr(uint32_t msr, uint64_t val) {
		uint32_t hi = val >> 32, lo = val;
		__asm__ volatile ("wrmsr" : : "a" (lo), "d" (hi), "c" (msr));
	}
	
	const uint32_t Efer = 0xC0000080;
	const uint32_t Star = 0xC0000081;
	const uint32_t LStar = 0xC0000082;
	const uint32_t SFMask = 0xC0000084;
	
	static inline void reboot() {
		uint64_t a[2] = { 0 };
		lidt(a);
		__asm__ volatile ("int3");
	}
}

#endif
