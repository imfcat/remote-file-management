import os
import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.config import Config
from server.handlers import (
    list_root_folders, list_files, delete_file,
    file_info, file_content
)
from utils.scanner import scan_directory
from database.connection import SessionLocal


config = Config()


@asynccontextmanager
async def lifespan(app: FastAPI):
    if not config.check_root_dir():
        print(f"[FATAL] ROOT_DIR 检查失败: {config.root_dir}")
        os._exit(1)

    # 启动目录扫描
    asyncio.create_task(scan_directory(config.root_dir, SessionLocal))
    yield
    print('服务器已关闭')


app = FastAPI(lifespan=lifespan)

# 配置CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.get("/list_root_folders")(list_root_folders)
app.get("/list_files")(list_files)
app.delete("/delete_file")(delete_file)
app.get("/file_info")(file_info)
app.get("/file_content")(file_content)