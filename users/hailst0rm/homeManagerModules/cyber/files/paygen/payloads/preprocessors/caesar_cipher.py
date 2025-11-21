#!/usr/bin/env python3
"""
Caesar cipher preprocessor.

Encrypts/decrypts data using Caesar cipher with configurable shift.
"""

import sys
import json
import base64


def caesar_cipher(data: bytes, shift: int, decrypt: bool = False) -> bytes:
    """
    Apply Caesar cipher to data.
    
    Args:
        data: Data to encrypt/decrypt
        shift: Shift value (0-255)
        decrypt: If True, decrypt instead of encrypt
    
    Returns:
        Encrypted/decrypted bytes
    """
    if decrypt:
        shift = -shift
    
    # Apply shift to each byte
    result = bytes((b + shift) % 256 for b in data)
    return result


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
        
        # Get shift value (default: 13 for ROT13)
        shift = args.get('shift', 13)
        if not isinstance(shift, int):
            try:
                shift = int(shift)
            except ValueError:
                raise ValueError(f"Invalid shift value: {shift}")
        
        # Ensure shift is in valid range
        shift = shift % 256
        
        # Get operation mode
        decrypt = args.get('decrypt', False)
        if isinstance(decrypt, str):
            decrypt = decrypt.lower() in ('true', 'yes', '1')
        
        # Apply cipher
        result = caesar_cipher(data, shift, decrypt)
        
        # Output as JSON
        output = {
            'encrypted' if not decrypt else 'decrypted': base64.b64encode(result).decode('ascii'),
            'shift': shift,
            'size': len(result)
        }
        
        print(json.dumps(output))
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
