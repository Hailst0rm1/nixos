#!/usr/bin/env python3
"""
Gzip compression preprocessor.

Compresses data using gzip compression.
"""

import sys
import json
import gzip
import base64


def compress_data(data: bytes, level: int = 9) -> bytes:
    """
    Compress data using gzip.
    
    Args:
        data: Data to compress
        level: Compression level (1-9, default: 9 for maximum compression)
    
    Returns:
        Compressed bytes
    """
    return gzip.compress(data, compresslevel=level)


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
        
        # Get compression level (1-9)
        level = args.get('level', 9)
        if not isinstance(level, int):
            try:
                level = int(level)
            except ValueError:
                raise ValueError(f"Invalid compression level: {level}")
        
        # Ensure level is in valid range
        if level < 1 or level > 9:
            raise ValueError(f"Compression level must be 1-9, got: {level}")
        
        # Compress
        compressed = compress_data(data, level)
        
        # Calculate compression ratio
        original_size = len(data)
        compressed_size = len(compressed)
        ratio = (1 - compressed_size / original_size) * 100 if original_size > 0 else 0
        
        # Output as JSON
        result = {
            'compressed': base64.b64encode(compressed).decode('ascii'),
            'original_size': original_size,
            'compressed_size': compressed_size,
            'compression_ratio': f"{ratio:.1f}%",
            'level': level
        }
        
        print(json.dumps(result))
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
