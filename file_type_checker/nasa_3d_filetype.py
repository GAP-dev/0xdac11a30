import os

def detect_format(filepath):
    with open(filepath, 'rb') as f:
        header = f.read(128)

    # glb (glTF binary)
    if header[:4] == b'glTF':
        return 'glb'

    # STL - ASCII or binary
    if header[:5].lower() == b'solid':
        return 'stl'
    if header[:2] == b'\x00\x00':  # crude binary STL check (optional)
        return 'stl'

    # OBJ - ASCII, usually starts with "o " or "v "
    try:
        text = header.decode('utf-8', errors='ignore')
        if text.startswith("o ") or text.startswith("v "):
            return 'obj'
    except:
        pass

    # LWO - LightWave Object
    if header[:4] == b'FORM' and header[8:12] == b'LWO2':
        return 'lwo'

    # BLEND - Blender
    if header[:7] == b'BLENDER':
        return 'blend'

    return None

def rename_with_format(filepath):
    detected = detect_format(filepath)
    if detected:
        new_name = f"{filepath}.{detected}"
        os.rename(filepath, new_name)
        print(f"✅ Renamed to: {new_name}")
    else:
        print("❌ Unknown or unsupported 3D model format.")

# 예시 사용
rename_with_format("1175")