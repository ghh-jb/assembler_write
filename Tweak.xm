#import <mach-o/dyld.h>
#import <string.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import "substrate.h"
#import <pthread.h>
#import <mach/vm_map.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <sys/mman.h>
#import <substrate.h>

// some useful assembly instructions I have shipped with this code.
uint32_t nop = 0xD503201F;
uint32_t mov_x9_0x40 = 0xD2800809; // 0x090880D2
uint32_t movi_v02s_0x1 = 0x0F000420;
uint32_t movk_lsl_x9_0x40 = 0xF2E08489; // 0x8984E0F2
uint32_t mov_x0_0x1 = 0xD2800020; // 0x200080D2
uint32_t mov_x0_0x0 = 0xD2800000; // 0x000080D2
uint32_t ret = 0xD65F03C0; // 0xC0035FD6
uint32_t mov_x0_0x256 = 0xD2804AC0; // 0xC04A80D2
uint32_t mov_x0_0xffff = 0xD29FFFE0; // 0xE0FF9FD2
uint32_t mov_x8_oxc8 = 0xD2801908; // 0x081980D2

/*
 * chain to return 1337.0 in assembly
 * mov        w0, #0x2000 			-> 0x00008452
 * movk       w0, #0x44a7, lsl #16  -> 0xE094A872
 * fmov       s0, w0				-> 0x0000271E
 * ret 								-> 0xC0035FD6
*/
uint32_t mov_w0_0x2000 = 0x52840000;
uint32_t movk_w0_0x44a7_lsl_16 = 0x72A894E0;
uint32_t fmov_s0_w0 = 0x1E270000;

uint64_t getSlide(const char* imagePath) {
	uint64_t slide = 0;
	while (!slide) {
		sleep(1);
		for (uint32_t i = 0; i < _dyld_image_count(); i++) {
			const char* imageName = _dyld_get_image_name(i);
			if (strstr(imageName, imagePath) != NULL) {
				NSLog(@"[assembler_write] image: %s", imageName);
				slide =  _dyld_get_image_vmaddr_slide(i);
			}
		}
	}
	return slide;
}

int kernwrite(uint32_t src, uint64_t dst) {
	vm_size_t size = sizeof(src);
	vm_address_t addr = (vm_address_t)dst;

	kern_return_t kr = vm_protect(
		mach_task_self(),
		addr,
		size,
		FALSE,
		VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
	if (kr != KERN_SUCCESS) {
		NSLog(@"[assembler_write] failed to unprotect memory at address: 0x%llx", dst);
	}

	memcpy((void *)dst, &src, size);

	kr = vm_protect(
		mach_task_self(),
		addr,
		size,
		FALSE,
		VM_PROT_READ | VM_PROT_EXECUTE);
	if (kr != KERN_SUCCESS) {
		NSLog(@"[assembler_write] failed to protect memory back at address: 0x%llx", dst);
	} else {
		NSLog(@"[assembler_write] wrote 0x%x -> 0x%llx", src, dst);
	}
	return kr;
}
void generate_branch_insn_array(uint64_t target_addr, uint32_t insn_array[5]) {
	uint16_t part0 = (target_addr >> 0) & 0xFFFF;
	uint16_t part1 = (target_addr >> 16) & 0xFFFF;
	uint16_t part2 = (target_addr >> 32) & 0xFFFF;
	uint16_t part3 = (target_addr >> 48) & 0xFFFF;
	insn_array[0] = 0xD2800000 | (3 << 21) | (part3 << 5) | 16;  // movz x16, #part3, LSL #48
	insn_array[1] = 0xF2800000 | (2 << 21) | (part2 << 5) | 16;  // movk x16, #part2, LSL #32
	insn_array[2] = 0xF2800000 | (1 << 21) | (part1 << 5) | 16;  // movk x16, #part1, LSL #16
	insn_array[3] = 0xF2800000 | (0 << 21) | (part0 << 5) | 16;  // movk x16, #part0, LSL #0
	insn_array[4] = 0xD61F0200;  								 // br x16
}

void logger(void) {
	NSLog(@"[assembler_write] this should not be called.");
	return;
}



void* patchfind(void* args) {
	NSLog(@"[assembler_write] Starting assembler writer...");
	char execPath[PATH_MAX];
	uint32_t execPathSize = PATH_MAX;
	_NSGetExecutablePath(execPath, &execPathSize);
	NSLog(@"[assembler_write] executable at: %s", execPath);

	uint64_t execSlide = getSlide("SOmeRandomFramework"); // Insert your framework / app executable
	NSLog(@"[assembler_write] Slide: 0x%llx", execSlide);


	uint32_t off = 0x41414141; //  this is the offset in binaryninja for example. Insert it here.
	// FIXME: FIND YOUR OFFSET.
	uint64_t dst = execSlide + off; // this is the destination. Due to ASLR the binary in memory must be calculated using _dyld_get_image_vmaddr_slide to get execSlide of the binary. Them we add our offset to it.
	kernwrite(mov_x0_0x1, dst);  // this is the main write primitive. 
	// As the first argument it takes the assembly insn as little-endian hex. (due to iOS being little-endian) 
	// as the second - destination with exec slide included.
	dst = dst + 4; // I suppose this must land on the next instruction?
	kernwrite(ret, dst); // Write again, now ret. End of function. 
	// This is an example of code intercepting the function at offset 0x41414141 that must return bool, but now returns True at any time.

	// ATTENTION!!! I have NOT TESTED this with PAC! This might NOT work with it. I have userspace PAC *COMPLETELY* disabled on my Fugu15_Rootful.


	// And here is an example of how to make a jump to your own code, though I dont really know how can it be used here...
	void (*ptr)(void) = logger; // get a raw void* pointer to our function
	
	uint64_t target_addr = (uint64_t)ptr; // convert to uint64 to match input of fn
	uint32_t insn[5]; // there we will store instructions to jump to.
	generate_branch_insn_array(target_addr, insn); // this generates the chain of instructions and puts to insn array

	// and now just walk through then to write them to desired addr.
	for (int i = 0; i<= 4; i++) {
		kernwrite(dst, insn[i]);
		dst = dst + 4; // should land on next insn
	}
	kernwrite(dst, ret); // return. It should now print a not invoked function

// Add your cheats here.
	return NULL;
}

%ctor {
	pthread_t cheat_thread;
	pthread_create(&cheat_thread, NULL, patchfind, NULL);
}