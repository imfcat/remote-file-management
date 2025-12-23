import mimetypes
import os, asyncio
from pathlib import Path
from sqlalchemy.orm import Session
from core.logger import debug, info, warning, error
from database.models import FileRecord, FolderRecord
from utils.needs_update import folder_changed
from utils.utils import get_md5, get_image_size
from utils.thumb import make_thumb
from utils.cleaner import clean_missing_resources
import tqdm
import concurrent.futures

IMAGE_EXT = {'.jpg', '.jpeg', '.jpe', '.png', '.bmp', '.gif', '.tiff'}
VIDEO_EXT = {'.mp4', '.avi', '.mov', '.mkv'}
TEXT_EXT = {'.txt', '.md', '.log'}

async def scan_directory(root_path: str, session_factory):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _scan, Path(root_path), session_factory)


def _scan(root_path: Path, session_factory):
    session = session_factory()
    try:
        # 获取所有一级文件夹
        dirs = [
            p.name for p in root_path.iterdir()
            if p.is_dir() and not p.name.startswith('.')
        ]

        all_media_files = []
        for folder in dirs:
            folder_path = root_path / folder
            if not folder_changed(session, str(root_path), folder):
                info(f'(SKIP) {folder} 无变动')
                continue
            info(f'(SCAN) {folder} 载入')
            count_files = 0

            # 清除该文件夹旧记录
            session.query(FileRecord).filter(FileRecord.root_folder == folder).delete()

            # 遍历文件夹内文件
            for dir_path, _, filenames in os.walk(folder_path):
                dir_path = Path(dir_path)
                for file in filenames:
                    count_files = count_files + 1
                    _process_file(session, root_path, folder, dir_path, file)
                    ext = os.path.splitext(file)[1].lower()
                    # 收集图片和视频文件用于生成缩略图
                    if ext in IMAGE_EXT or ext in VIDEO_EXT:
                        all_media_files.append(str(dir_path / file))

            # 批量生成两种尺寸的缩略图
            batch_thumbs(all_media_files, root_path)
            # 更新文件夹时间戳
            mtime = os.stat(os.path.join(root_path, folder)).st_mtime
            session.merge(FolderRecord(folder=folder, last_mtime=mtime, count=count_files))

        # 清理
        clean_missing_resources(session, root_path, dirs)

        session.commit()
        info(f'(SUCCESS) 载入完成')
    finally:
        session.close()


def _process_file(session: Session, root_dir: Path, folder: str, dirpath: Path, file: str):
    file_path = dirpath / file
    try:
        stat = file_path.stat()
        file_size = stat.st_size
        file_name = file_path.name
        ext = file_path.suffix.lower()

        file_type = 'other'
        width, height = None, None
        if ext in IMAGE_EXT:
            file_type = 'image'
            width, height = get_image_size(str(file_path))
        elif ext in VIDEO_EXT:
            file_type = 'video'
        elif ext in TEXT_EXT:
            file_type = 'text'

        mime_type = get_mime_type(str(file_path))
        rel_path = file_path.relative_to(root_dir).as_posix()
        md5_hash = get_md5(str(file_path)) or 'unknown'

        record = FileRecord(
            file_path=str(file_path),
            file=rel_path,
            root_folder=folder,
            file_name=file_name,
            file_type=file_type,
            mime_type=mime_type,
            file_size=file_size,
            md5_hash=md5_hash,
            width=width,
            height=height
        )
        session.merge(record)
        debug(f'添加文件 {file_path}')
    except Exception as e:
        error(f'处理文件失败 {file_path} : {e}')


def get_mime_type(file_path: str) -> str:
    """获取文件MIME"""
    mime_type, _ = mimetypes.guess_type(file_path)
    return mime_type or 'application/octet-stream'


def batch_thumbs(file_list, root_dir, workers: int = 8):
    """批量生成两种尺寸的缩略图"""
    root = Path(root_dir)
    cache_dir = root / '.cache'

    cache_dir.mkdir(parents=True, exist_ok=True)

    # 检查目录是否可写
    if not os.access(str(cache_dir), os.W_OK):
        error(f".cache目录不可写：{cache_dir}，停止生成缩略图")
        return

    (cache_dir / 'thumb').mkdir(parents=True, exist_ok=True)
    (cache_dir / 'medium').mkdir(parents=True, exist_ok=True)

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = []
        for file_path in tqdm.tqdm(file_list, desc="生成缩略图"):
            # 提交小缩略图任务
            future_thumb = pool.submit(
                make_thumb, file_path, root_dir, 300, 'thumb'
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
                # thumb_path = future.result()
                # logger.info(f"{size_type}缩略图生成成功：{thumb_path}")
                future.result()
            except Exception as e:
                error(f"[Thumb] {size_type}缩略图生成失败：{file_path} → {e}")