import os, asyncio
from sqlalchemy.orm import Session
from models import FileRecord
from folder_mtime import FolderMtime
from needs_update import folder_changed
from utils import get_md5, get_image_size
from datetime import datetime
import logging

logger = logging.getLogger('scanner')

IMAGE_EXT = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff'}
VIDEO_EXT = {'.mp4', '.avi', '.mov', '.mkv'}
TEXT_EXT = {'.txt', '.md', '.log'}

async def scan_directory(root_path: str, session_factory):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _scan, root_path, session_factory)

def _scan(root_path: str, session_factory):
    session = session_factory()
    # 拿到所有一级文件夹
    dirs = [name for name in os.listdir(root_path)
            if os.path.isdir(os.path.join(root_path, name)) and not name.startswith('.')]
    for folder in dirs:
        if not folder_changed(session, root_path, folder):
            logger.info(f'{folder} 无变动 (SKIP)')
            continue
        logger.info(f'{folder} 载入 (SCAN)')
        # 先清该文件夹旧记录
        session.query(FileRecord).filter(FileRecord.root_folder == folder).delete()
        for dirpath, _, filenames in os.walk(os.path.join(root_path, folder)):
            for file in filenames:
                _process_file(session, root_path, folder, dirpath, file)
        # 更新时间戳
        mtime = os.stat(os.path.join(root_path, folder)).st_mtime
        session.merge(FolderMtime(folder=folder, last_mtime=mtime))
    session.commit()
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
    except Exception as e:
        logger.error(f'处理文件失败 {file_path} : {e}')