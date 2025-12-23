import shutil
from pathlib import Path
from sqlalchemy.orm import Session
from core.logger import info, warning, error, debug
from database.models import FileRecord, FolderRecord


def delete_folder_if_exists(folder_path: Path, desc: str = "目录"):
    """
    目录清除
    :param folder_path: 要删除的目录
    :param desc: 目录描述
    :return:
    """
    if folder_path.exists() and folder_path.is_dir():
        try:
            shutil.rmtree(folder_path)
            info(f'(CLEAN) 成功删除{desc}目录 {folder_path}')
        except Exception as e:
            error(f'(CLEAN) 删除{desc}目录失败 {folder_path} → {e}')
    else:
        debug(f'(CLEAN) {desc}目录不存在，无需删除 {folder_path}')


def clean_missing_resources(session: Session, root_path: Path, existing_dirs: list[str]):
    """
    清理数据库中存在但实际不存在的数据
    - 删除对应缩略图缓存
    - 删除关联的FileRecord与FolderRecord记录
    :param session:
    :param root_path: 扫描的根目录路径
    :param existing_dirs: 当前实际存在的一级文件夹列表
    :return:
    """

    # 获取数据库中记录的所有文件夹
    db_folders = [row[0] for row in session.query(FolderRecord.folder).all()]
    # 找出数据库中有但实际不存在的文件夹
    deleted_folders = [f for f in db_folders if f not in existing_dirs]

    if not deleted_folders:
        return  # 无需要清理的文件夹，直接返回

    warning(f'(CLEAN) {deleted_folders} 已不存在，将清理')

    # 删除对应的缩略图缓存
    cache_dir = root_path / '.cache'
    for folder in deleted_folders:
        thumb_dir = cache_dir / 'thumb' / folder
        medium_dir = cache_dir / 'medium' / folder
        delete_folder_if_exists(thumb_dir, f'<{folder}>小缩略图')
        delete_folder_if_exists(medium_dir, f'<{folder}>大缩略图')

    # 删除关联的FileRecord
    delete_file_count = session.query(FileRecord).filter(
        FileRecord.root_folder.in_(deleted_folders)
    ).delete(synchronize_session=False)
    warning(f'(CLEAN) 清理关联文件记录数 {delete_file_count}')

    # 删除FolderRecord
    delete_folder_count = session.query(FolderRecord).filter(
        FolderRecord.folder.in_(deleted_folders)
    ).delete(synchronize_session=False)
    warning(f'(CLEAN) 清理文件夹记录数 {delete_folder_count}')