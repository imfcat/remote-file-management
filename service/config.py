from sqlalchemy import Column, String
from models import Base

class Config(Base):
    __tablename__ = 'config'
    key   = Column(String, primary_key=True)
    value = Column(String, nullable=False)