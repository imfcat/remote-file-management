import logging
import tkinter as tk
from threading import Lock

LEVEL_COLOR = {
    'DEBUG': '#AAAAAA',
    'INFO': '#FFFFFF',
    'WARNING': '#FFD700',
    'ERROR': '#FF6347'
}

TAG_COLOR = {
    '(SCAN)': '#00FFFF',
    '(THUMB)': '#98FB98',
    '(CLEAN)': '#FFA500',
    '(SUCCESS)': '#32CD32',
    '(SKIP)': '#808080',
}

LEVEL_MAP = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR
}


# 全局日志管理器
class GlobalLoggerManager:
    _instance = None
    _lock = Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    # 初始化核心日志器
                    cls._instance.logger = logging.getLogger("global_gui_logger")
                    cls._instance.logger.setLevel(logging.DEBUG)
                    cls._instance.logger.propagate = False

                    # 初始化GUI日志处理器
                    cls._instance.gui_handler = None

                    cls._add_console_handler(cls._instance.logger)
        return cls._instance

    @staticmethod
    def _add_console_handler(logger):
        """控制台日志处理器"""
        if not any(isinstance(h, logging.StreamHandler) for h in logger.handlers):
            formatter = logging.Formatter(
                '[%(asctime)s] [%(levelname)s] %(message)s',
                datefmt='%H:%M:%S'
            )
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(formatter)
            logger.addHandler(console_handler)

    def bind_gui(self, text_widget: tk.Text, log_level_var: tk.StringVar):
        """绑定GUI的日志显示组件"""
        # 移除旧日志
        if self.gui_handler:
            self.logger.removeHandler(self.gui_handler)

        self.gui_handler = GuiLogger(text_widget, log_level_var)
        self.logger.addHandler(self.gui_handler)

    def get_logger(self) -> logging.Logger:
        """获取全局日志器"""
        return self.logger


# GUI日志处理器
class GuiLogger(logging.Handler):
    def __init__(self, text_widget: tk.Text, log_level_var: tk.StringVar):
        super().__init__()
        self.text_widget = text_widget
        self.log_level_var = log_level_var
        self.setFormatter(logging.Formatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%H:%M:%S'
        ))

        self.text_widget.config(state=tk.NORMAL)
        for color_name in set(LEVEL_COLOR.values()).union(TAG_COLOR.values()):
            self.text_widget.tag_config(color_name, foreground=color_name)
        self.text_widget.config(state=tk.DISABLED)

    def emit(self, record):
        """输出日志到GUI文本框"""
        try:
            # 获取当前选择的日志级别
            current_level = self.log_level_var.get()
            current_level_val = LEVEL_MAP.get(current_level, logging.INFO)

            # 只输出大于当前级别的日志
            if record.levelno >= current_level_val:
                msg = self.format(record)

                color = LEVEL_COLOR.get(record.levelname, '#FFFFFF')

                for tag, tag_color in TAG_COLOR.items():
                    if tag in record.getMessage():
                        color = tag_color
                        break

                self.text_widget.after(0, self._write_log, msg, color)
        except Exception:
            self.handleError(record)

    def _write_log(self, msg: str, color: str):
        """实际写入日志到文本框"""
        self.text_widget.config(state=tk.NORMAL)

        # 如果当前消息是进度更新
        progress_keyword = "(THUMB) 缩略图生成进度"
        if progress_keyword in msg:
            last_line_content = self.text_widget.get("end-2c linestart", "end-1c")
            if progress_keyword in last_line_content:
                self.text_widget.delete("end-2c linestart", "end-1c")

        self.text_widget.insert(tk.END, msg + '\n', color)
        self.text_widget.config(state=tk.DISABLED)
        self.text_widget.see(tk.END)


def get_global_logger() -> logging.Logger:
    """获取全局日志器"""
    return GlobalLoggerManager().get_logger()


def debug(msg: str):
    """输出DEBUG级日志"""
    get_global_logger().debug(msg)


def info(msg: str):
    """输出INFO级日志"""
    get_global_logger().info(msg)


def warning(msg: str):
    """输出WARNING级日志"""
    get_global_logger().warning(msg)


def error(msg: str):
    """输出ERROR级日志"""
    get_global_logger().error(msg)