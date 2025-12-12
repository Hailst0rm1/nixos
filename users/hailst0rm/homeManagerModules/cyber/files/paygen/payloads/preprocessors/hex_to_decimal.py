#!/usr/bin/env python3
# preprocessors/hex_to_decimal.py
import sys
import json

def main():
    args = json.load(sys.stdin)
    hex_value = args['hex_value']
    
    # Remove 0x prefix if present
    if hex_value.startswith('0x') or hex_value.startswith('0X'):
        hex_value = hex_value[2:]
    
    # Convert hex to decimal
    decimal_value = int(hex_value, 16)
    
    # Output as plain string (not JSON) so it renders directly in templates
    print(str(decimal_value))

if __name__ == "__main__":
    main()
