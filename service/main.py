import uvicorn
from core.config import Config
from core.logger import setup_logger
from server.app import app


def main():
    logger = setup_logger("server_cli")
    config = Config()

    # 检查配置
    if not config.check_root_dir():
        logger.error(f"ROOT_DIR 检查失败: {config.root_dir}")
        return

    logger.info(f"服务将在 http://0.0.0.0:{config.port} 启动")
    logger.info(f"根目录: {config.root_dir}")

    # 启动服务器
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=config.port,
        log_level="info"
    )


if __name__ == "__main__":
    main()