from sqlalchemy.orm import Session
from database.models import Config

# 配置键常量
CONFIG_KEYS = {
    "root_dir": "root_dir",
    "port": "port"
}


def _get_config(session: Session, key: str, default: str | None = None) -> str | None:
    """通用配置读取"""
    config = session.query(Config).filter(Config.key == key).first()
    return config.value if config else default


def _set_config(session: Session, key: str, value: str) -> None:
    """通用配置写入"""
    # 存在则更新，不存在则插入
    session.merge(Config(key=key, value=value))
    session.commit()


def get_root_dir(session: Session) -> str | None:
    """获取根目录配置"""
    return _get_config(session, CONFIG_KEYS["root_dir"])


def set_root_dir(session: Session, path: str) -> None:
    """设置根目录配置"""
    if not path:
        raise ValueError("根目录路径不能为空")
    _set_config(session, CONFIG_KEYS["root_dir"], path)


def get_port(session: Session) -> int | None:
    """获取端口配置"""
    port_str = _get_config(session, CONFIG_KEYS["port"])
    return int(port_str) if port_str and port_str.isdigit() else None


def set_port(session: Session, port: int) -> None:
    """设置端口配置"""
    if not isinstance(port, int) or port < 1 or port > 65535:
        raise ValueError("端口必须是1-65535之间的整数")
    _set_config(session, CONFIG_KEYS["port"], str(port))
