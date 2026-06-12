"""Run: python scripts\\check_tf_env.py  (from repo root, venv optional)"""
import platform
import struct
import sys

v = sys.version_info
bits = struct.calcsize("P") * 8

print("--- Environment (TensorFlow on Windows) ---")
print(f"Python:     {v.major}.{v.minor}.{v.micro}")
print(f"Bits:       {bits}")
print(f"Machine:    {platform.machine()}")
print(f"Executable: {sys.executable}")
print()

if bits != 64:
    print("PROBLEM: TensorFlow needs 64-bit Python. Reinstall Python x86-64.")
elif v.major != 3:
    print("PROBLEM: Use CPython 3.x.")
elif v.minor < 9:
    print("PROBLEM: Python too old. Use 3.11 or 3.12.")
elif v.minor >= 13:
    print("PROBLEM: TensorFlow has no stable pip wheels for Python 3.13+ on Windows (you have 3.14).")
    print("FIX:     Recreate the venv with 3.10 or 3.11, e.g. if `py --list` shows 3.10:")
    print('           deactivate')
    print("           rmdir /s /q .venv")
    print("           py -3.10 -m venv .venv")
    print("           .venv\\Scripts\\activate.bat")
    print("           pip install -r api\\requirements.txt")
else:
    print("OK: This Python (3.9–3.12, 64-bit) usually works with pip install tensorflow.")
print()
print("If pip still fails, use a clean virtualenv with Python 3.10+ and: pip install -r api/requirements.txt")
print("  npm run dev   # starts API + frontend when deps are installed")
