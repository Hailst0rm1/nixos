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
    
    # VBA has a limit of 25 line continuations per statement
    # Use 24 lines max (23 continuations + 1 final line) to stay safe
    max_lines = 24
    
    # Create list of decimal values (VBA uses decimal, not hex)
    bytes_list = [str(b) for b in data]
    total_bytes = len(bytes_list)
    
    # Calculate bytes per line to fit within max_lines
    bytes_per_line = (total_bytes + max_lines - 1) // max_lines  # Ceiling division
    
    lines = []
    
    # Build single Array() statement with line continuations
    for i in range(0, total_bytes, bytes_per_line):
        line_chunk = bytes_list[i:i + bytes_per_line]
        if i == 0:
            # First line includes the variable assignment
            lines.append(f"{var_name} = Array({', '.join(line_chunk)}, _")
        elif i + bytes_per_line >= total_bytes:
            # Last line, no continuation
            lines.append(f"    {', '.join(line_chunk)})")
        else:
            # Middle lines with continuation
            lines.append(f"    {', '.join(line_chunk)}, _")
    
    # Output formatted code directly as string
    print('\n'.join(lines))

if __name__ == "__main__":
    main()
