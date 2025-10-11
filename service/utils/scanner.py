import os, asyncio
from pathlib import Path
from sqlalchemy.orm import Session
from database.models import FileRecord, FolderMtime
from utils.needs_update import folder_changed
from utils.utils import get_md5, get_image_size
import logging
from utils.thumb import make_thumb
import tqdm
import concurrent.futures

logger = logging.getLogger('scanner')

IMAGE_EXT = {'.jpg', '.jpeg', '.jpe', '.png', '.bmp', '.gif', '.tiff'}
VIDEO_EXT = {'.mp4', '.avi', '.mov', '.mkv'}
TEXT_EXT = {'.txt', '.md', '.log'}

async def scan_directory(root_path: str, session_factory):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _scan, root_path, session_factory)


def _scan(root_path: str, session_factory):
    session = session_factory()
    try:
        root = Path(root_path)
        # 获取所有一级文件夹
        dirs = [name for name in os.listdir(root_path)
                if os.path.isdir(os.path.join(root_path, name))
                and not name.startswith('.')]

        all_media_files = []
        for folder in dirs:
            if not folder_changed(session, root_path, folder):
                logger.info(f'{folder} 无变动 (SKIP)')
                continue
            logger.info(f'{folder} 载入 (SCAN)')

            # 清除该文件夹旧记录
            session.query(FileRecord).filter(FileRecord.root_folder == folder).delete()

            # 遍历文件夹内文件
            for dir_path, _, filenames in os.walk(os.path.join(root_path, folder)):
                for file in filenames:
                    _process_file(session, root_path, folder, dir_path, file)
                    ext = os.path.splitext(file)[1].lower()
                    # 收集图片和视频文件用于生成缩略图
                    if ext in IMAGE_EXT or ext in VIDEO_EXT:
                        all_media_files.append(os.path.join(dir_path, file))

            # 批量生成两种尺寸的缩略图
            batch_thumbs(all_media_files, root_path)
            # 更新文件夹时间戳
            mtime = os.stat(os.path.join(root_path, folder)).st_mtime
            session.merge(FolderMtime(folder=folder, last_mtime=mtime))

        session.commit()
    finally:
        session.close()


def _process_file(session: Session, root_dir: str, folder: str, dirpath: str, file: str):
    file_path = os.path.join(dirpath, file)
    try:
        stat = os.stat(file_path)
        file_size = stat.st_size
        file_name, ext = os.path.splitext(file)
        ext = ext.lower()

        file_type = 'other'
        width, height = None, None
        if ext in IMAGE_EXT:
            file_type = 'image'
            width, height = get_image_size(file_path)
        elif ext in VIDEO_EXT:
            file_type = 'video'
        elif ext in TEXT_EXT:
            file_type = 'text'

        md5_hash = get_md5(file_path) or 'unknown'

        record = FileRecord(
            file_path=file_path,
            root_folder=folder,
            file_name=file,
            file_type=file_type,
            file_size=file_size,
            md5_hash=md5_hash,
            width=width,
            height=height
        )
        session.merge(record)
        logger.info(f'添加文件 {file_path}')
    except Exception as e:
        logger.error(f'处理文件失败 {file_path} : {e}')


def batch_thumbs(file_list, root_dir, workers: int = 8):
    """批量生成两种尺寸的缩略图"""
    root = Path(root_dir)
    cache_dir = root / '.cache'

    cache_dir.mkdir(parents=True, exist_ok=True)

    # 检查目录是否可写
    if not os.access(str(cache_dir), os.W_OK):
        logger.error(f".cache目录不可写：{cache_dir}，停止生成缩略图")
        return

    (cache_dir / 'thumb').mkdir(parents=True, exist_ok=True)
    (cache_dir / 'medium').mkdir(parents=True, exist_ok=True)

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = []
        for file_path in tqdm.tqdm(file_list, desc="生成缩略图"):
            # 提交小缩略图任务
            future_thumb = pool.submit(
                make_thumb, file_path, root_dir, 200, 'thumb'
            )
            futures.append((file_path, '小', future_thumb))

            # 提交中等压缩图任务
            future_medium = pool.submit(
                make_thumb, file_path, root_dir, 2000, 'medium'
            )
            futures.append((file_path, '中等', future_medium))

        # 处理任务结果
        for file_path, size_type, future in futures:
            try:
                thumb_path = future.result()
                logger.info(f"{size_type}缩略图生成成功：{thumb_path}")
            except Exception as e:
                logger.error(f"[Thumb] {size_type}缩略图生成失败：{file_path} → {e}")