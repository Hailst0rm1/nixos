#!/usr/bin/env python3
"""
C byte array formatter preprocessor.

Converts bytes to C unsigned char array format.
"""

import sys
import json
import base64


def format_c_bytes(data: bytes, bytes_per_line: int = 15, var_name: str = "buf") -> str:
    """
    Format bytes as C unsigned char array.
    
    Args:
        data: Data to format
        bytes_per_line: Number of bytes per line (default: 15)
        var_name: Variable name for the array (default: "buf")
    
    Returns:
        C unsigned char array declaration string
    """
    lines = []
    lines.append(f"unsigned char {var_name}[] = \"")
    
    # Format bytes in C string hex format
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        hex_values = ''.join(f'\\x{b:02x}' for b in chunk)
        if i + bytes_per_line < len(data):
            lines.append(f"{hex_values}\"")
            lines.append("\"")
        else:
            lines.append(f"{hex_values}\";")
    
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
        bytes_per_line = args.get('bytes_per_line', 15)
        if not isinstance(bytes_per_line, int):
            try:
                bytes_per_line = int(bytes_per_line)
            except ValueError:
                bytes_per_line = 15
        
        var_name = args.get('var_name', 'buf')
        
        # Format as C byte array
        formatted = format_c_bytes(data, bytes_per_line, var_name)
        
        # Output formatted code directly (will be stored as string in template context)
        print(formatted)
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
