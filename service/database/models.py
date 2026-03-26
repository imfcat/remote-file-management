from sqlalchemy import Column, Integer, String, Float
from sqlalchemy.ext.declarative import declarative_base

# 基础模型类
Base = declarative_base()


class Config(Base):
    """系统配置"""
    __tablename__ = 'config'

    key = Column(String, primary_key=True, comment="配置键")
    value = Column(String, nullable=False, comment="配置值")


class FolderRecord(Base):
    """根文件夹记录"""
    __tablename__ = 'folder'

    folder = Column(String, primary_key=True, comment="一级文件夹名")
    last_mtime = Column(Float, nullable=False, comment="最后修改时间戳")
    count = Column(Integer, nullable=True, comment="文件数")
    mark = Column(String, nullable=True, comment="标记")


class FileRecord(Base):
    """文件记录"""
    __tablename__ = 'files'

    id = Column(Integer, primary_key=True, autoincrement=True, comment="自增ID")
    file_path = Column(String, unique=True, nullable=False, comment="文件完整路径")
    file = Column(String, nullable=False, comment="文件路径")
    root_folder = Column(String, nullable=False, comment="根文件夹")
    file_name = Column(String, nullable=False, comment="文件名")
    file_type = Column(String, nullable=False, comment="文件类型：image/video/text/other")
    mime_type = Column(String, nullable=False, comment='文件mime')
    file_size = Column(Integer, nullable=False, comment="文件大小（字节）")
    md5_hash = Column(String, nullable=False, comment="文件MD5哈希值")
    width = Column(Integer, nullable=True, comment="图片宽度（仅图片类型）")
    height = Column(Integer, nullable=True, comment="图片高度（仅图片类型）")
    deleted_at = Column(Integer, default=0, nullable=False, comment="删除时间戳")