import os
import sys
import uvicorn
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from database import SessionLocal
from models import FileRecord
from scanner import scan_directory
import asyncio
from pathlib import Path
import urllib.parse
import shutil
from config_ops import get_root_dir, set_root_dir
import threading
import uvicorn
from typing import Optional

DEFAULT_ROOT_DIR = r"C:\Windows\Web\Wallpaper"
DEFAULT_PORT     = 8081

RECYCLE_FOLDER = ".recycle"

IS_RECYCLE_FOLDER = False
SERVER: Optional[uvicorn.Server] = None
SERVER_THREAD: Optional[threading.Thread] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    _check_root_or_exit()
    asyncio.create_task(scan_directory(ROOT_DIR, SessionLocal))
    yield
    print('closed')

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def load_root_dir() -> str:
    with SessionLocal() as session:
        db_path = get_root_dir(session)
        if db_path and Path(db_path).is_dir():
            print(f"[DB] 使用配置目录: {db_path}")
            return db_path
        if Path(DEFAULT_ROOT_DIR).is_dir():
            set_root_dir(session, DEFAULT_ROOT_DIR)
            print(f"[DB] 未配置使用默认目录: {DEFAULT_ROOT_DIR}")
            return DEFAULT_ROOT_DIR
        raise RuntimeError("默认目录不存在且数据库未配置")

ROOT_DIR = load_root_dir()

# 启动检查
def _check_root_or_exit() -> None:
    if not os.path.isdir(ROOT_DIR):
        print(f"[FATAL] ROOT_DIR 不存在: {ROOT_DIR}")
        sys.exit(1)

    dirs = [name for name in os.listdir(ROOT_DIR)
            if os.path.isdir(os.path.join(ROOT_DIR, name))
            and not name.startswith('.')]
    if not dirs:
        print(f"[FATAL] ROOT_DIR 下没有一级文件夹: {ROOT_DIR}")
        sys.exit(1)

    try:
        os.makedirs(os.path.join(ROOT_DIR, RECYCLE_FOLDER), exist_ok=True)
        IS_RECYCLE_FOLDER = True
    except:
        print(f"'.recycle' 目录创建失败")

    print(f"[OK] ROOT_DIR 检查通过: {ROOT_DIR}  含 {len(dirs)} 个一级文件夹")

@app.get("/list_root_folders")
async def list_root_folders():
    dirs = [name for name in os.listdir(ROOT_DIR)
            if os.path.isdir(os.path.join(ROOT_DIR, name))
            and not name.startswith('.')]
    return {"folders": dirs}

@app.get("/list_files")
async def list_files(
    folder: str = Query(...),
    sort: str = Query("path"),
    order: str = Query("asc")
):
    session: Session = SessionLocal()
    query = session.query(FileRecord).filter(FileRecord.root_folder == folder)
    if sort == "name":
        query = query.order_by(FileRecord.file_name.asc() if order == "asc" else FileRecord.file_name.desc())
    elif sort == "type":
        query = query.order_by(FileRecord.file_type.asc() if order == "asc" else FileRecord.file_type.desc())
    elif sort == "size":
        query = query.order_by(FileRecord.file_size.asc() if order == "asc" else FileRecord.file_size.desc())
    else:
        query = query.order_by(FileRecord.file_path.asc() if order == "asc" else FileRecord.file_path.desc())
    files = query.all()
    session.close()
    return {"files": [f.__dict__ for f in files]}

@app.delete("/delete_file")
async def delete_file(file_path: str):
    if not IS_RECYCLE_FOLDER:
        print(f"'.recycle' 目录不存在，无法安全删除文件")
    file_path = urllib.parse.unquote(file_path)
    src = Path(file_path)
    if not src.exists():
        session: Session = SessionLocal()
        session.query(FileRecord).filter(FileRecord.file_path == file_path).delete()
        session.commit(); session.close()
        return {"message": "文件已不存在，仅清理数据库"}

    # 构造回收站路径
    root_folder = src.relative_to(ROOT_DIR).parts[0]
    rel_path = src.relative_to(Path(ROOT_DIR) / root_folder)

    recycle_dir = Path(ROOT_DIR) / RECYCLE_FOLDER / root_folder / rel_path.parent
    recycle_dir.mkdir(parents=True, exist_ok=True)
    dst = recycle_dir / src.name

    try:
        shutil.move(str(src), str(dst))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"移动失败: {e}")

    # 删库记录
    session: Session = SessionLocal()
    session.query(FileRecord).filter(FileRecord.file_path == file_path).delete()
    session.commit(); session.close()

    return {"message": "已移入回收站", "recycle_path": str(dst)}

@app.get("/file_info")
async def file_info(file_path: str):
    session: Session = SessionLocal()
    record = session.query(FileRecord).filter(FileRecord.file_path == file_path).first()
    session.close()
    if not record:
        raise HTTPException(status_code=404, detail="数据库无此文件")
    return record.__dict__

@app.get("/file_content")
async def file_content(file_path: str = Query(...)):
    file_path = urllib.parse.unquote(file_path)
    abs_path = Path(file_path).resolve()
    root = Path(ROOT_DIR).resolve()

    if root not in abs_path.parents and root != abs_path:
        raise HTTPException(status_code=403, detail="路径非法")

    if not abs_path.exists() or not abs_path.is_file():
        raise HTTPException(status_code=404, detail="文件不存在")

    return FileResponse(abs_path, filename=abs_path.name)

def run_server(host: str, port: int):
    global SERVER, SERVER_THREAD
    config = uvicorn.Config(app, host=host, port=port, log_config=None)
    SERVER = uvicorn.Server(config)
    SERVER_THREAD = threading.current_thread()
    SERVER.run()

def stop_server():
    global SERVER
    if SERVER is None:
        return False
    SERVER.should_exit = True
    SERVER = None
    return True

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8081)