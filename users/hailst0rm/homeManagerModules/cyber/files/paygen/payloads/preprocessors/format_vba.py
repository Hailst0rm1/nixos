#!/usr/bin/env python3
# preprocessors/format_vba.py
import sys
import json
import base64

def main():
    args = json.load(sys.stdin)
    data = base64.b64decode(args['data'])
    
    # Format as VBA byte array
    var_name = args.get('var_name', 'buf')
    bytes_per_line = args.get('bytes_per_line', 15)
    
    # Create list of decimal values (VBA uses decimal, not hex)
    bytes_list = [str(b) for b in data]
    
    # Split into lines with proper VBA continuation
    lines = []
    for i in range(0, len(bytes_list), bytes_per_line):
        chunk = bytes_list[i:i + bytes_per_line]
        if i == 0:
            # First line includes the array declaration
            lines.append(f"{var_name} = Array({', '.join(chunk)}, _")
        elif i + bytes_per_line >= len(bytes_list):
            # Last line, no continuation
            lines.append(f"    {', '.join(chunk)})")
        else:
            # Middle lines with continuation
            lines.append(f"    {', '.join(chunk)}, _")
    
    # Output formatted code directly as string
    print('\n'.join(lines))

if __name__ == "__main__":
    main()
