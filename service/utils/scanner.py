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
                info(f'(SKIP) 目录 [{folder}] 无变动')
                continue
            info(f'(SCAN) 扫描目录 [{folder}]')
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

            info(f'(SCAN) 目录 [{folder}] 扫描到 {count_files} 个文件')
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
        error(f"(THUMB) .cache目录不可写：{cache_dir}，停止生成缩略图")
        return

    (cache_dir / 'thumb').mkdir(parents=True, exist_ok=True)
    (cache_dir / 'medium').mkdir(parents=True, exist_ok=True)

    info(f"(THUMB) 开始缩略图任务 {len(file_list)}")

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        future_to_info = {}
        for file_path in file_list:
            f1 = pool.submit(make_thumb, file_path, root_dir, 300, 'thumb')
            f2 = pool.submit(make_thumb, file_path, root_dir, 2000, 'medium')
            future_to_info[f1] = (file_path, '小')
            future_to_info[f2] = (file_path, '中等')

        total_tasks = len(future_to_info)
        completed = 0
        report_step = max(1, total_tasks // 10)

        for future in concurrent.futures.as_completed(future_to_info):
            file_path, size_type = future_to_info[future]
            completed += 1
            try:
                future.result()
                debug(f"(THUMB) 成功：{size_type}图 [{Path(file_path).name}]")
            except Exception as e:
                error(f"(THUMB) 失败：{size_type}图 [{Path(file_path).name}] -> {e}")

            if completed % report_step == 0 or completed == total_tasks:
                percentage = (completed / total_tasks) * 100
                info(f"(THUMB) 缩略图生成进度: {completed}/{total_tasks} ({percentage:.1f}%)")