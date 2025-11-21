#!/usr/bin/env python3
"""
C# byte array formatter preprocessor.

Converts bytes to C# byte array format.
"""

import sys
import json
import base64


def format_csharp_bytes(data: bytes, bytes_per_line: int = 16, var_name: str = "payload") -> str:
    """
    Format bytes as C# byte array.
    
    Args:
        data: Data to format
        bytes_per_line: Number of bytes per line (default: 16)
        var_name: Variable name for the array (default: "payload")
    
    Returns:
        C# byte array declaration string
    """
    lines = []
    lines.append(f"byte[] {var_name} = new byte[{len(data)}] {{")
    
    # Format bytes in hex
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        hex_values = ', '.join(f'0x{b:02x}' for b in chunk)
        lines.append(f"    {hex_values},")
    
    # Remove trailing comma from last line
    if lines:
        lines[-1] = lines[-1].rstrip(',')
    
    lines.append("};")
    
    return '\n'.join(lines)


def main():
    """Main entry point for the preprocessor."""
    try:
        # Read JSON input from stdin
        args = json.load(sys.stdin)
        
        # Get input data
        data_input = args.get('data') or args.get('input') or args.get('shellcode')
        if not data_input:
            raise ValueError("Missing required argument: 'data', 'input', or 'shellcode'")
        
        # Convert input to bytes
        try:
            # Try base64 first
            data = base64.b64decode(data_input)
        except Exception:
            # Fall back to UTF-8 string
            if isinstance(data_input, str):
                data = data_input.encode('utf-8')
            else:
                data = bytes(data_input)
        
        # Get formatting options
        bytes_per_line = args.get('bytes_per_line', 16)
        if not isinstance(bytes_per_line, int):
            try:
                bytes_per_line = int(bytes_per_line)
            except ValueError:
                bytes_per_line = 16
        
        var_name = args.get('var_name', 'payload')
        
        # Format as C# byte array
        formatted = format_csharp_bytes(data, bytes_per_line, var_name)
        
        # Output as plain string (for template insertion)
        print(formatted)
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
