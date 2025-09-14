import logging
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog
import ttkbootstrap as ttk
from ttkbootstrap.constants import *

from config_ops import set_root_dir, get_root_dir, get_port, set_port
from database import SessionLocal
from main import DEFAULT_ROOT_DIR, DEFAULT_PORT, SERVER, run_server, stop_server

LEVEL_COLOR = {
    'INFO': 'white',
    'WARNING': 'yellow',
    'ERROR': 'red'
}

def load_config():
    with SessionLocal() as session:
        root = get_root_dir(session) or DEFAULT_ROOT_DIR
        port = get_port(session)   or DEFAULT_PORT

        if get_root_dir(session) is None:
            set_root_dir(session, DEFAULT_ROOT_DIR)
        if get_port(session) is None:
            set_port(session, str(DEFAULT_PORT))
        return root, int(port)

ROOT_DIR, PORT = load_config()

class GuiLogger(logging.Handler):
    def __init__(self, text_widget):
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
        self.text_widget.config(state=NORMAL)
        self.text_widget.tag_config(color, foreground=color)
        self.text_widget.insert(END, msg + '\n', color)
        self.text_widget.config(state=DISABLED)
        self.text_widget.see(END)

class ServerGUI(ttk.Window):
    def __init__(self):
        super().__init__(title='图片管理服务端', themename='darkly', size=(940, 600))
        self.log_text = None
        self.dir_var = None
        self.port_var = None
        self.logger = None
        self.build_ui()
        self.after(100, self.poll_log)

    def build_ui(self):
        # 顶部配置栏
        top = ttk.Frame(self)
        top.pack(fill='x', padx=10, pady=10)

        ttk.Label(top, text='端口:').pack(side='left', padx=5)
        self.port_var = tk.IntVar(value=int(get_port(SessionLocal()) or DEFAULT_PORT))
        self.port_var.trace_add('write', self._save_port)
        ttk.Spinbox(top, from_=1024, to=65535, textvariable=self.port_var, width=6).pack(side='left', padx=5)

        ttk.Label(top, text='根目录:').pack(side='left', padx=5)
        self.dir_var = tk.StringVar(value=get_root_dir(SessionLocal()) or DEFAULT_ROOT_DIR)
        self.dir_var.trace_add('write', self._save_dir)
        ttk.Entry(top, textvariable=self.dir_var, width=40).pack(side='left', padx=5)
        ttk.Button(top, text='浏览', command=self.browse_dir, style=SECONDARY).pack(side='left', padx=5)
        ttk.Button(top, text='启动', command=self.start_server, style=SUCCESS).pack(side='left', padx=5)
        ttk.Button(top, text="停止", command=self.stop_server, style=DANGER).pack(side='left', padx=5)


        # 日志区域
        bottom = ttk.Frame(self)
        bottom.pack(fill='both', expand=YES, padx=10, pady=10)
        self.log_text = tk.Text(bottom, state='disabled', wrap='none')
        self.log_text.pack(fill='both', expand=YES)
        scroll = ttk.Scrollbar(bottom, command=self.log_text.yview)
        scroll.pack(side='right', fill='y')
        self.log_text.config(yscrollcommand=scroll.set)

        # 绑定日志
        self.logger = logging.getLogger()
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(GuiLogger(self.log_text))

    def _save_port(self, *args):
        with SessionLocal() as session:
            set_port(session, str(self.port_var.get()))

    def _save_dir(self, *args):
        with SessionLocal() as session:
            set_root_dir(session, self.dir_var.get())

    def browse_dir(self):
        path = tk.filedialog.askdirectory(title='选择图片根目录')
        if path:
            self.dir_var.set(path)

    def start_server(self):
        port = int(self.port_var.get())
        root = self.dir_var.get()
        if not Path(root).is_dir():
            ttk.dialogs.Messagebox.show_error('目录不存在！', '错误')
            return

        with SessionLocal() as session:
            set_root_dir(session, root)
            set_port(session, str(port))

        self.log('>>> 服务启动中 ...')
        threading.Thread(target=run_server, args=('0.0.0.0', port), daemon=True).start()

    def stop_server(self):
        if stop_server():
            self.log('>>> 服务已停止', level=logging.INFO)
        else:
            self.log('>>> 服务未运行', level=logging.WARNING)

    def poll_log(self):
        self.after(100, self.poll_log)

    def log(self, msg, level=logging.INFO):
        self.logger.log(level, msg)


if __name__ == '__main__':
    root = ServerGUI()
    root.mainloop()