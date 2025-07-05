import filetype
import os

def rename_with_filetype(filepath):
    kind = filetype.guess(filepath)
    if kind:
        new_filepath = f"{filepath}.{kind.extension}"
        os.rename(filepath, new_filepath)
        print(f"✅ Renamed: {new_filepath} ({kind.mime})")
    else:
        print("❌ Unknown file type. Could not determine extension.")

rename_with_filetype("1175")