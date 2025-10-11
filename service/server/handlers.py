import os
import shutil
import urllib.parse
from pathlib import Path
from fastapi import HTTPException, Query, Depends
from sqlalchemy.orm import Session
from database.connection import get_db
from database.models import FileRecord
from core.config import config


def list_root_folders():
    dirs = [name for name in os.listdir(config.root_dir)
            if os.path.isdir(os.path.join(config.root_dir, name))
            and not name.startswith('.')]
    return {"folders": dirs}


def list_files(
        folder: str = Query(...),
        sort: str = Query("path"),
        order: str = Query("asc"),
        db: Session = Depends(get_db)
):
    query = db.query(FileRecord).filter(FileRecord.root_folder == folder)

    # 排序处理
    if sort == "name":
        query = query.order_by(FileRecord.file_name.asc() if order == "asc" else FileRecord.file_name.desc())
    elif sort == "type":
        query = query.order_by(FileRecord.file_type.asc() if order == "asc" else FileRecord.file_type.desc())
    elif sort == "size":
        query = query.order_by(FileRecord.file_size.asc() if order == "asc" else FileRecord.file_size.desc())
    else:
        query = query.order_by(FileRecord.file_path.asc() if order == "asc" else FileRecord.file_path.desc())

    files = query.all()
    return {"files": [f.__dict__ for f in files]}


def delete_file(
        file_path: str,
        db: Session = Depends(get_db)
):
    if not config.is_recycle_folder:
        print(f"'.recycle' 目录不存在，无法安全删除文件")

    file_path = urllib.parse.unquote(file_path)
    src = Path(file_path)

    if not src.exists():
        db.query(FileRecord).filter(FileRecord.file_path == file_path).delete()
        db.commit()
        return {"message": "文件已不存在，仅清理数据库"}

    # 构造回收站路径
    root_folder = src.relative_to(config.root_dir).parts[0]
    rel_path = src.relative_to(Path(config.root_dir) / root_folder)

    recycle_dir = Path(config.root_dir) / config.recycle_folder / root_folder / rel_path.parent
    recycle_dir.mkdir(parents=True, exist_ok=True)
    dst = recycle_dir / src.name

    try:
        shutil.move(str(src), str(dst))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"移动失败: {e}")

    db.query(FileRecord).filter(FileRecord.file_path == file_path).delete()
    db.commit()
    return {"message": "已移入回收站", "recycle_path": str(dst)}


def file_info(
        file_path: str,
        db: Session = Depends(get_db)
):
    record = db.query(FileRecord).filter(FileRecord.file_path == file_path).first()
    if not record:
        raise HTTPException(status_code=404, detail="数据库无此文件")
    return record.__dict__


def file_content(file_path: str = Query(...)):
    from fastapi.responses import FileResponse

    file_path = urllib.parse.unquote(file_path)
    abs_path = Path(file_path).resolve()
    root = Path(config.root_dir).resolve()

    if root not in abs_path.parents and root != abs_path:
        raise HTTPException(status_code=403, detail="路径非法")

    if not abs_path.exists() or not abs_path.is_file():
        raise HTTPException(status_code=404, detail="文件不存在")

    return FileResponse(abs_path, filename=abs_path.name)