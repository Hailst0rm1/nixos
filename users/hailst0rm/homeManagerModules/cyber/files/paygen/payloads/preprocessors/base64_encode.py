#!/usr/bin/env python3
"""
Base64 encoding preprocessor.

Encodes data to base64 format.
"""

import sys
import json
import base64


def main():
    """Main entry point for the preprocessor."""
    try:
        # Read JSON input from stdin
        args = json.load(sys.stdin)
        
        # Get input data
        data_input = args.get('data') or args.get('input') or args.get('shellcode')
        if not data_input:
            raise ValueError("Missing required argument: 'data', 'input', or 'shellcode'")
        
        # Check if data is already base64-encoded (from payload_builder)
        if args.get('data_is_base64', False):
            # Data is base64-encoded bytes, decode it first
            data = base64.b64decode(data_input)
        elif isinstance(data_input, str):
            # Check if already base64
            try:
                # Try to decode - if it works, it's already base64
                test_decode = base64.b64decode(data_input)
                # Use the decoded bytes
                data = test_decode
            except Exception:
                # Not base64, encode as UTF-8
                data = data_input.encode('utf-8')
        else:
            data = bytes(data_input)
        
        # Encode to base64
        encoded = base64.b64encode(data).decode('ascii')
        
        # Check output format preference
        output_format = args.get('format', 'string')
        
        if output_format == 'json':
            # Output as JSON object
            result = {
                'encoded': encoded,
                'size': len(encoded),
                'original_size': len(data)
            }
            print(json.dumps(result))
        else:
            # Output as plain string (default)
            print(encoded)
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
