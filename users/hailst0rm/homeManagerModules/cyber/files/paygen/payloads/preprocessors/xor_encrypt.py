#!/usr/bin/env python3
"""
XOR encryption preprocessor.

Encrypts data using XOR cipher with automatic key generation support.
"""

import sys
import json
import secrets
import base64


def xor_encrypt(data: bytes, key: bytes) -> bytes:
    """
    XOR encrypt data with the given key.
    
    Args:
        data: Data to encrypt
        key: Encryption key (will be repeated to match data length)
    
    Returns:
        Encrypted bytes
    """
    # Repeat key to match data length
    extended_key = (key * (len(data) // len(key) + 1))[:len(data)]
    
    # XOR each byte
    encrypted = bytes(d ^ k for d, k in zip(data, extended_key))
    return encrypted


def generate_key(length: int = 16) -> bytes:
    """
    Generate a random XOR key.
    
    Args:
        length: Key length in bytes (default: 16)
    
    Returns:
        Random key bytes
    """
    return secrets.token_bytes(length)


def main():
    """Main entry point for the preprocessor."""
    try:
        # Read JSON input from stdin
        args = json.load(sys.stdin)
        
        # Get input data
        shellcode_input = args.get('shellcode') or args.get('input') or args.get('data')
        if not shellcode_input:
            raise ValueError("Missing required argument: 'shellcode', 'input', or 'data'")
        
        # Convert input to bytes (handle base64 or raw string)
        try:
            # Try base64 first
            shellcode = base64.b64decode(shellcode_input)
        except Exception:
            # Fall back to UTF-8 string
            if isinstance(shellcode_input, str):
                shellcode = shellcode_input.encode('utf-8')
            else:
                shellcode = bytes(shellcode_input)
        
        # Get or generate key
        key_input = args.get('key', '')
        
        if not key_input or key_input.lower() == 'auto':
            # Auto-generate key
            key = generate_key(16)
        else:
            # Use provided key
            if isinstance(key_input, str):
                # Try hex first
                try:
                    key = bytes.fromhex(key_input)
                except ValueError:
                    # Fall back to UTF-8
                    key = key_input.encode('utf-8')
            else:
                key = bytes(key_input)
        
        # Encrypt
        encrypted = xor_encrypt(shellcode, key)
        
        # Output as JSON with encrypted data and key
        result = {
            'encrypted': base64.b64encode(encrypted).decode('ascii'),
            'key': base64.b64encode(key).decode('ascii'),
            'key_hex': key.hex(),
            'size': len(encrypted)
        }
        
        print(json.dumps(result))
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
