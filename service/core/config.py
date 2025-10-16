import os
from pathlib import Path
from database.connection import init_db, get_db, db_context
from database.config_ops import get_root_dir, set_root_dir, get_port, set_port

DEFAULT_ROOT_DIR = r"C:\Windows\Web\Wallpaper"
DEFAULT_PORT = 8081
RECYCLE_FOLDER = ".recycle"


class Config:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if hasattr(self, '_initialized'):
            return
        self._initialized = True

        init_db()

        with db_context() as db:
            self.root_dir = self._load_root_dir(db)
            self.port = self._load_port(db)
        self.recycle_folder = RECYCLE_FOLDER
        self.is_recycle_folder = False

    def _load_root_dir(self, db) -> str:
        # 从数据库读取
        db_path = get_root_dir(db)
        if db_path and Path(db_path).is_dir():
            return db_path

        # 使用默认值
        default_path = DEFAULT_ROOT_DIR
        if Path(default_path).is_dir():
            set_root_dir(db, default_path)  # 写入数据库
            return default_path

        # 无效提示
        raise RuntimeError(f"默认目录不存在且数据库未配置: {default_path}")

    def _load_port(self, db) -> int:
        # 从数据库读取
        port = get_port(db)
        if port:
            return port

        # 使用默认值并写入
        set_port(db, DEFAULT_PORT)  # 写入数据库
        return DEFAULT_PORT

    def save_root_dir(self, root_dir: str):
        with db_context() as db:
            set_root_dir(db, root_dir)
        self.root_dir = root_dir

    def save_port(self, port: int):
        with db_context() as db:
            set_port(db, port)
        self.port = port

    def check_root_dir(self) -> bool:
        if not Path(self.root_dir).is_dir():
            return False

        # 检查一级文件夹
        dirs = [name for name in os.listdir(self.root_dir)
                if os.path.isdir(os.path.join(self.root_dir, name))
                and not name.startswith('.')]

        if not dirs:
            return False

        # 检查回收站
        try:
            os.makedirs(os.path.join(self.root_dir, self.recycle_folder), exist_ok=True)
            self.is_recycle_folder = True
        except:
            self.is_recycle_folder = False

        return True

config = Config()