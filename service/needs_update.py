import os
from sqlalchemy.orm import Session
from folder_mtime import FolderMtime

def folder_changed(session: Session, root_dir: str, folder: str) -> bool:
    """True: 需要重新扫描"""
    record = session.query(FolderMtime).filter(FolderMtime.folder == folder).first()
    folder_path = os.path.join(root_dir, folder)
    if not os.path.isdir(folder_path):
        return False
    current_mtime = os.stat(folder_path).st_mtime
    if record is None:
        return True
    return current_mtime > record.last_mtime + 1