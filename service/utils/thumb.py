import pyvips
from pathlib import Path

IMAGE_EXT = {'.jpg', '.jpeg', '.jpe', '.png', '.bmp', '.gif', '.tiff'}
VIDEO_EXT = {'.mp4', '.avi', '.mov', '.mkv'}

def make_thumb(originalPath: str, rootDir: str, size: int, subdir: str) -> str:
    """生成指定尺寸和子目录的缩略图
    Args:
        originalPath: 原始文件路径
        rootDir: 根目录
        size: 缩略图最大边长
        subdir: 子目录（thumb/medium）
    """
    root = Path(rootDir)
    cache_dir = root / '.cache'

    # 获取相对路径和原始文件扩展名
    rel_path = Path(originalPath).relative_to(root)
    original_ext = rel_path.suffix.lower()

    if original_ext in VIDEO_EXT:
        output_ext = '.jpg'
    elif original_ext in IMAGE_EXT:
        output_ext = original_ext
    else:
        raise ValueError(f"不支持的文件类型: {originalPath}")

    # 构建缩略图保存路径
    thumb_path = cache_dir / subdir / rel_path.with_suffix(output_ext)
    thumb_path.parent.mkdir(parents=True, exist_ok=True)

    # 按比例缩放，最大边为指定size
    image = pyvips.Image.thumbnail(originalPath, size)

    # 根据格式设置不同的保存参数
    write_args = {}
    if output_ext in ('.jpg', '.jpeg'):
        write_args['Q'] = 85  # JPG质量
        write_args['interlace'] = True  # 渐进式JPG

    image.write_to_file(str(thumb_path), **write_args)
    return str(thumb_path)