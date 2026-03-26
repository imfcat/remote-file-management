import os
import time
import shutil
import urllib.parse
from pathlib import Path
from typing import Optional
from fastapi import HTTPException, Query, Depends
from sqlalchemy.orm import Session
from database.connection import get_db
from database.models import FolderRecord, FileRecord
from core.config import config


def list_root_folders(db: Session = Depends(get_db)):
    query = db.query(FolderRecord)
    return {"folders": query.all()}


def list_files(
        folder: Optional[str] = Query(None, description="一级文件夹"),
        sort: Optional[str] = Query(None, description="排序字段"),
        order: str = Query("asc", description="排序顺序"),
        is_deleted: bool = Query(False, description="获取删除文件"),
        db: Session = Depends(get_db)
):
    query = db.query(FileRecord)

    if is_deleted:
        query = query.filter(FileRecord.deleted_at > 0)
        if folder:
            query = query.filter(FileRecord.root_folder == folder)

        if not sort:
            sort = "deleted_at"
            if order != "asc":
                order = "desc"
            else:
                # 若前端没传 order，由于参数默认值是 "asc"，我们在这里强制改写为 "desc" 更符合常理
                # 如果你想严格遵守传入的 asc，可以去掉这行赋值
                order = "desc"
    else:
        query = query.filter(FileRecord.root_folder == folder, FileRecord.deleted_at == 0)

        if not sort:
            sort = "path"

    # 排序处理
    is_asc = (order == "asc")
    if sort == "name":
        query = query.order_by(FileRecord.file_name.asc() if is_asc else FileRecord.file_name.desc())
    elif sort == "type":
        query = query.order_by(FileRecord.mime_type.asc() if is_asc else FileRecord.mime_type.desc())
    elif sort == "size":
        query = query.order_by(FileRecord.file_size.asc() if is_asc else FileRecord.file_size.desc())
    elif sort == "deleted_at":
        query = query.order_by(FileRecord.deleted_at.asc() if is_asc else FileRecord.deleted_at.desc())
    else:
        query = query.order_by(FileRecord.file_path.asc() if is_asc else FileRecord.file_path.desc())

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
        db.query(FileRecord).filter(FileRecord.file_path == file_path).update({"deleted_at": int(time.time())})
        db.commit()
        return {"message": "文件已不存在，仅在数据库中标记为已删除"}

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

    # 查询FileRecord记录，获取root_folder
    file_record = db.query(FileRecord).filter(FileRecord.file_path == file_path).first()
    if file_record:
        # 更新删除时间戳
        file_record.deleted_at = int(time.time())
        db_root_folder = file_record.root_folder

        # 更新count
        if db_root_folder:
            folder_record = db.query(FolderRecord).filter(FolderRecord.folder == db_root_folder).first()
            if folder_record:
                folder_record.count = (folder_record.count or 0) - 1
                if folder_record.count < 0:
                    folder_record.count = 0

    db.commit()
    return {"message": "已移入回收站", "recycle_path": str(dst)}


# 移出回收站
def restore_file(
        file_path: str = Query(...),
        db: Session = Depends(get_db)
):
    file_path = urllib.parse.unquote(file_path)

    file_record = db.query(FileRecord).filter(FileRecord.file_path == file_path).first()
    if not file_record:
        raise HTTPException(status_code=404, detail="数据库无此文件记录")

    if file_record.deleted_at == 0:
        return {"message": "文件未被删除，无需恢复"}

    src = Path(file_path)
    root_folder = src.relative_to(config.root_dir).parts[0]
    rel_path = src.relative_to(Path(config.root_dir) / root_folder)

    recycle_dir = Path(config.root_dir) / config.recycle_folder / root_folder / rel_path.parent
    recycle_file = recycle_dir / src.name

    if recycle_file.exists():
        src.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.move(str(recycle_file), str(src))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"恢复物理文件失败: {e}")

    file_record.deleted_at = 0

    folder_record = db.query(FolderRecord).filter(FolderRecord.folder == file_record.root_folder).first()
    if folder_record:
        folder_record.count = (folder_record.count or 0) + 1

    db.commit()
    return {"message": "已移出回收站并恢复数据", "restore_path": str(src)}


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

    file_path = urllib.parse.unquote(f'{config.root_dir}/{file_path}')
    abs_path = Path(file_path).resolve()
    root = Path(config.root_dir).resolve()

    if root not in abs_path.parents and root != abs_path:
        raise HTTPException(status_code=403, detail="路径非法")

    if not abs_path.exists() or not abs_path.is_file():
        raise HTTPException(status_code=404, detail="文件不存在")

    return FileResponse(abs_path, filename=abs_path.name)


def folder_mark(
        folder: str,
        mark: str,
        db: Session = Depends(get_db)
):
    record = db.query(FolderRecord).filter(FolderRecord.folder == folder).update(
        {FolderRecord.mark: mark}
    )
    if not record:
        raise HTTPException(status_code=404, detail="数据库无此文件")
    return {"message": "标记成功", "mark": str(mark)}