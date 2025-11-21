#!/usr/bin/env python3
"""
AES-256-CBC encryption preprocessor.

Encrypts data using AES-256 in CBC mode with automatic key/IV generation.
"""

import sys
import json
import secrets
import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad


def aes_encrypt(data: bytes, key: bytes, iv: bytes = None) -> tuple[bytes, bytes]:
    """
    AES-256-CBC encrypt data.
    
    Args:
        data: Data to encrypt
        key: 32-byte encryption key
        iv: 16-byte initialization vector (optional, will be generated if None)
    
    Returns:
        Tuple of (encrypted_data, iv)
    """
    if len(key) != 32:
        raise ValueError("AES-256 requires a 32-byte key")
    
    # Generate IV if not provided
    if iv is None:
        iv = secrets.token_bytes(16)
    elif len(iv) != 16:
        raise ValueError("AES requires a 16-byte IV")
    
    # Create cipher and encrypt
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded_data = pad(data, AES.block_size)
    encrypted = cipher.encrypt(padded_data)
    
    return encrypted, iv


def generate_key() -> bytes:
    """
    Generate a random AES-256 key.
    
    Returns:
        32-byte random key
    """
    return secrets.token_bytes(32)


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
        
        # Get or generate key
        key_input = args.get('key', '')
        
        if not key_input or key_input.lower() == 'auto':
            # Auto-generate key
            key = generate_key()
        else:
            # Use provided key
            if isinstance(key_input, str):
                # Try hex first
                try:
                    key = bytes.fromhex(key_input)
                except ValueError:
                    # Try base64
                    try:
                        key = base64.b64decode(key_input)
                    except Exception:
                        # Fall back to UTF-8 (will fail if not 32 bytes)
                        key = key_input.encode('utf-8')
            else:
                key = bytes(key_input)
        
        # Get or generate IV
        iv_input = args.get('iv', '')
        
        if not iv_input or iv_input.lower() == 'auto':
            iv = None  # Will be auto-generated in aes_encrypt
        else:
            # Use provided IV
            if isinstance(iv_input, str):
                # Try hex first
                try:
                    iv = bytes.fromhex(iv_input)
                except ValueError:
                    # Try base64
                    try:
                        iv = base64.b64decode(iv_input)
                    except Exception:
                        # Fall back to UTF-8
                        iv = iv_input.encode('utf-8')
            else:
                iv = bytes(iv_input)
        
        # Encrypt
        encrypted, iv = aes_encrypt(data, key, iv)
        
        # Output as JSON
        result = {
            'encrypted': base64.b64encode(encrypted).decode('ascii'),
            'key': base64.b64encode(key).decode('ascii'),
            'key_hex': key.hex(),
            'iv': base64.b64encode(iv).decode('ascii'),
            'iv_hex': iv.hex(),
            'size': len(encrypted)
        }
        
        print(json.dumps(result))
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
