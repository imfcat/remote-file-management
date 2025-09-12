from sqlalchemy.orm import Session
from config import Config

ROOT_KEY = 'root_dir'

def get_root_dir(session: Session) -> str | None:
    row = session.query(Config).filter(Config.key == ROOT_KEY).first()
    return row.value if row else None

def set_root_dir(session: Session, path: str) -> None:
    session.merge(Config(key=ROOT_KEY, value=path))
    session.commit()