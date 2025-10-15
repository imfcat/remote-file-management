import pyvips
import subprocess
import tempfile
from pathlib import Path
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("thumb_generator")

IMAGE_EXT = {'.jpg', '.jpeg', '.jpe', '.png', '.bmp', '.gif', '.tiff'}
VIDEO_EXT = {'.mp4', '.avi', '.mov', '.mkv'}


def get_image_dimensions(image_path: str) -> tuple[int, int]:
    """获取图像的宽度和高度"""
    try:
        image_path = str(Path(image_path).resolve())
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"图像文件不存在: {image_path}")

        image = pyvips.Image.new_from_file(image_path, access='sequential')
        return (image.width, image.height)
    except Exception as e:
        logger.error(f"获取图像尺寸失败: {str(e)}，路径: {image_path}")
        raise


def get_video_dimensions(video_path: str) -> tuple[int, int]:
    """使用ffmpeg获取视频的宽度和高度"""
    try:
        video_path = str(Path(video_path).resolve())
        if not os.path.exists(video_path):
            raise FileNotFoundError(f"视频文件不存在: {video_path}")

        result = subprocess.run(
            [
                "ffprobe", "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=width,height",
                "-of", "csv=p=0",
                video_path
            ],
            check=True,
            capture_output=True,
            text=True
        )
        width, height = map(int, result.stdout.strip().split(','))
        return (width, height)
    except subprocess.CalledProcessError as e:
        logger.error(f"ffprobe命令执行失败: {e.stderr}，视频路径: {video_path}")
        raise
    except FileNotFoundError:
        logger.error("未找到ffprobe，请确保ffmpeg已安装并添加到系统PATH中")
        raise
    except Exception as e:
        logger.error(f"获取视频尺寸失败: {str(e)}，视频路径: {video_path}")
        raise


def extract_video_frame(video_path: str, output_frame_path: str) -> bool:
    """使用ffmpeg从视频中提取第一帧作为图像"""
    try:
        video_path = str(Path(video_path).resolve())
        output_frame_path = str(Path(output_frame_path).resolve())

        if not os.path.exists(video_path):
            logger.error(f"视频文件不存在: {video_path}")
            return False

        # 输出目录验证
        output_dir = os.path.dirname(output_frame_path)
        os.makedirs(output_dir, exist_ok=True)

        # 删除旧文件
        if os.path.exists(output_frame_path):
            os.remove(output_frame_path)

        result = subprocess.run(
            [
                "ffmpeg", "-y",
                "-i", video_path,
                "-vframes", "1",
                "-q:v", "2",
                output_frame_path
            ],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            logger.error(f"ffmpeg错误输出: {result.stderr}")
            return False

        if not os.path.exists(output_frame_path) or os.path.getsize(output_frame_path) == 0:
            logger.error(
                f"ffmpeg未生成有效文件: {output_frame_path} (大小: {os.path.getsize(output_frame_path) if os.path.exists(output_frame_path) else 0})")
            return False

        # logger.info(f"成功提取视频帧: {output_frame_path} (大小: {os.path.getsize(output_frame_path)})")
        return True
    except Exception as e:
        logger.error(f"提取视频帧时发生错误: {str(e)}，视频路径: {video_path}")
        return False


def make_thumb(originalPath: str, rootDir: str, size: int, subdir: str) -> str:
    """生成指定尺寸和子目录的缩略图"""
    root = Path(rootDir)
    cache_dir = root / '.cache'
    originalPath = str(Path(originalPath).resolve())  # 统一转为绝对路径

    # 验证原始文件
    if not os.path.exists(originalPath):
        raise FileNotFoundError(f"原始文件不存在: {originalPath}")

    # 获取相对路径和原始文件扩展名
    try:
        rel_path = Path(originalPath).relative_to(root)
    except ValueError:
        # 处理原始文件不在rootDir的情况
        rel_path = Path(originalPath).name
    original_ext = rel_path.suffix.lower()

    if original_ext in VIDEO_EXT:
        output_ext = '.jpg'
        is_video = True
    elif original_ext in IMAGE_EXT:
        output_ext = original_ext
        is_video = False
    else:
        raise ValueError(f"不支持的文件类型: {originalPath} (扩展名: {original_ext})")

    # 构建缩略图保存路径
    if is_video:
        media_thumb_name = f'{rel_path.stem}{original_ext}{output_ext}'
        thumb_path = cache_dir / subdir / rel_path.parent / media_thumb_name
    else:
        thumb_path = cache_dir / subdir / rel_path.with_suffix(output_ext)

    thumb_path = thumb_path.resolve()
    thumb_path.parent.mkdir(parents=True, exist_ok=True)

    # 获取原始文件的尺寸
    try:
        if is_video:
            original_width, original_height = get_video_dimensions(originalPath)
        else:
            original_width, original_height = get_image_dimensions(originalPath)
        original_max_dim = max(original_width, original_height)
        # logger.info(f"原始文件尺寸: {original_width}x{original_height} (最大边: {original_max_dim})")
    except Exception as e:
        logger.warning(f"无法获取原始文件尺寸，将使用默认缩放行为: {str(e)}")
        original_max_dim = size + 1  # 强制使用缩放行为

    # 缩放
    if subdir == 'medium':
        need_scaling = original_max_dim > 2000
        target_size = 2000 if need_scaling else original_max_dim
    else:
        need_scaling = True
        target_size = size
    # logger.info(f"处理参数: 子目录={subdir}, 需要缩放={need_scaling}, 目标尺寸={target_size}")

    # 处理文件生成缩略图
    temp_frame_path = None
    try:
        if is_video:
            # 创建临时文件目录
            temp_dir = cache_dir / 'temp'
            temp_dir.mkdir(parents=True, exist_ok=True)

            # 创建临时文件
            with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False, dir=str(temp_dir)) as tmp_file:
                temp_frame_path = tmp_file.name
            # logger.info(f"创建临时文件: {temp_frame_path}")

            # 验证临时文件
            if not os.path.exists(temp_frame_path):
                raise FileNotFoundError(f"临时文件创建失败: {temp_frame_path}")

            # 提取视频帧
            if not extract_video_frame(originalPath, temp_frame_path):
                raise Exception(f"无法从视频中提取帧: {originalPath}")

            # 再次验证视频帧文件
            if not os.path.exists(temp_frame_path) or os.path.getsize(temp_frame_path) == 0:
                raise FileNotFoundError(f"视频帧文件无效: {temp_frame_path}")

            # 处理视频帧生成缩略图
            # logger.info(f"开始处理视频帧生成缩略图: {temp_frame_path}")
            if need_scaling:
                image = pyvips.Image.thumbnail(temp_frame_path, target_size)
            else:
                image = pyvips.Image.new_from_file(temp_frame_path)

            # 先将图像写入目标路径
            # logger.info(f"开始写入缩略图到目标路径: {thumb_path}")
            write_args = {'Q': 85, 'interlace': True}  # JPG参数
            image.write_to_file(str(thumb_path), **write_args)
            # logger.info(f"成功写入缩略图: {thumb_path}")

            # 确认写入后再删除临时文件
            if os.path.exists(temp_frame_path):
                os.remove(temp_frame_path)
                # logger.info(f"临时文件处理完成后删除: {temp_frame_path}")
            temp_frame_path = None  # 标记已删除

        else:
            # 处理图像文件
            if need_scaling:
                image = pyvips.Image.thumbnail(originalPath, target_size)
            else:
                image = pyvips.Image.new_from_file(originalPath)

            # 设置保存参数
            write_args = {}
            if output_ext in ('.jpg', '.jpeg'):
                write_args['Q'] = 85
                write_args['interlace'] = True
            elif output_ext == '.png':
                write_args['compression'] = 6
            elif output_ext == '.gif':
                write_args['colours'] = 256

            image.write_to_file(str(thumb_path), **write_args)
            # logger.info(f"成功生成图像缩略图: {thumb_path}")

    except Exception as e:
        logger.error(f"处理文件时出错: {str(e)}", exc_info=True)
        # 出错时尝试删除不完整的缩略图
        if os.path.exists(str(thumb_path)):
            os.remove(str(thumb_path))
            # logger.info(f"已删除不完整的缩略图: {thumb_path}")
        raise
    finally:
        # 最终清理
        if temp_frame_path and os.path.exists(temp_frame_path):
            try:
                os.remove(temp_frame_path)
                # logger.warning(f"finally块中清理残留临时文件: {temp_frame_path}")
            except Exception as e:
                logger.error(f"删除临时文件失败: {str(e)}, 文件路径: {temp_frame_path}")

    return str(thumb_path)