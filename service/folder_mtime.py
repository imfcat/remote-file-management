from sqlalchemy import Column, String, Float
from models import Base

class FolderMtime(Base):
    __tablename__ = 'folder_mtime'
    folder = Column(String, primary_key=True)   # 一级文件夹名
    last_mtime = Column(Float, nullable=False)