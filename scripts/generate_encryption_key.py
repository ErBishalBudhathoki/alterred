#!/usr/bin/env python3
"""
Generate encryption key for user settings.
Run this once and add the output to your .env file as ENCRYPTION_KEY.
"""

from cryptography.fernet import Fernet

if __name__ == "__main__":
    key = Fernet.generate_key().decode()
    print("=" * 60)
    print("Generated Encryption Key")
    print("=" * 60)
    print()
    print("Add this line to your .env file:")
    print()
    print(f"ENCRYPTION_KEY={key}")
    print()
    print("IMPORTANT: Keep this key secure and never commit it to version control!")
    print("=" * 60)
