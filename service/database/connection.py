import contextlib

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from database.models import Base


DATABASE_URL = "sqlite:///files.db"

engine = create_engine(
    DATABASE_URL,
    echo=False,  # debug
    connect_args={"check_same_thread": False}  # 多线程兼容
)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False
)


def init_db():
    Base.metadata.create_all(bind=engine)

def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()

@contextlib.contextmanager
def db_context() -> Session:
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception as e:
        db.rollback()
        raise e
    finally:
        db.close()