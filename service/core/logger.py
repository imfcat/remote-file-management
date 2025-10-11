import logging
from typing import Optional
import tkinter as tk

LEVEL_COLOR = {
    'INFO': 'white',
    'WARNING': 'yellow',
    'ERROR': 'red'
}


def setup_logger(name: Optional[str] = None, level=logging.INFO) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(level)

    if not logger.handlers:
        formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%H:%M:%S'
        )

        # 控制台处理
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

    return logger


class GuiLogger(logging.Handler):
    def __init__(self, text_widget: tk.Text):
        super().__init__()
        self.text_widget = text_widget
        self.setFormatter(logging.Formatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%H:%M:%S'
        ))

    def emit(self, record):
        msg = self.format(record)
        color = LEVEL_COLOR.get(record.levelname, 'white')
        self.text_widget.after(0, self._write, msg, color)

    def _write(self, msg, color):
        self.text_widget.config(state=tk.NORMAL)
        self.text_widget.tag_config(color, foreground=color)
        self.text_widget.insert(tk.END, msg + '\n', color)
        self.text_widget.config(state=tk.DISABLED)
        self.text_widget.see(tk.END)