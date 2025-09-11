import hashlib
import os
from PIL import Image

def get_md5(file_path):
    hash_md5 = hashlib.md5()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except Exception:
        return None

def get_image_size(file_path):
    try:
        with Image.open(file_path) as img:
            return img.size
    except Exception:
        return None, None