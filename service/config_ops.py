from sqlalchemy.orm import Session
from config import Config

ROOT_KEY = 'root_dir'
PORT_KEY = 'port'


def get_config(session: Session, key: str, default: str = None) -> str | None:
    row = session.query(Config).filter(Config.key == key).first()
    return row.value if row else default

def set_config(session: Session, key: str, value: str) -> None:
    session.merge(Config(key=key, value=value))
    session.commit()


def get_root_dir(session: Session) -> str | None:
    return get_config(session, ROOT_KEY)

def set_root_dir(session: Session, path: str) -> None:
    set_config(session, ROOT_KEY, path)


def get_port(session: Session) -> int | None:
    return get_config(session, PORT_KEY)

def set_port(session: Session, port: str) -> None:
    set_config(session, PORT_KEY, port)