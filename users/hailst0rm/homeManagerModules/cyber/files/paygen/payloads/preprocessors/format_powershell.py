#!/usr/bin/env python3
# preprocessors/format_powershell.py
import sys
import json
import base64

def main():
    args = json.load(sys.stdin)
    data = base64.b64decode(args['data'])
    
    # Format as PowerShell byte array
    var_name = args.get('var_name', 'buf')
    bytes_per_line = args.get('bytes_per_line', 15)
    
    # Create list of hex values
    bytes_list = [f'0x{b:02x}' for b in data]
    
    # Split into lines
    if bytes_per_line > 0:
        lines = []
        for i in range(0, len(bytes_list), bytes_per_line):
            chunk = bytes_list[i:i + bytes_per_line]
            lines.append(','.join(chunk))
        
        # Format with line breaks
        formatted = f"[Byte[]] ${var_name} = " + ','.join(lines)
    else:
        # Single line format
        formatted = f"[Byte[]] ${var_name} = " + ','.join(bytes_list)
    
    # Output formatted code directly as string
    print(formatted)

if __name__ == "__main__":
    main()
