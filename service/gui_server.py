# gui_server.py
import tkinter as tk
import ttkbootstrap as ttk
from ttkbootstrap.constants import *
import threading
import logging
import uvicorn
from pathlib import Path
from database import init_db, SessionLocal
from config_ops import set_root_dir, get_root_dir
from main import app, ROOT_DIR, RECYCLE_FOLDER
import os

LEVEL_COLOR = {
    'INFO': 'white',
    'WARNING': 'yellow',
    'ERROR': 'red'
}

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
        super().__init__(title='图片管理服务端', themename='darkly', size=(910, 600))
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
        self.port_var = tk.IntVar(value=8081)
        ttk.Spinbox(top, from_=1024, to=65535, textvariable=self.port_var, width=6).pack(side='left', padx=5)

        ttk.Label(top, text='ROOT_DIR:').pack(side='left', padx=5)
        self.dir_var = tk.StringVar(value=get_root_dir(SessionLocal()) or r'C:\Windows\Web\Wallpaper')
        ttk.Entry(top, textvariable=self.dir_var, width=40).pack(side='left', padx=5)
        ttk.Button(top, text='浏览', command=self.browse_dir, bootstyle=SECONDARY).pack(side='left', padx=5)
        ttk.Button(top, text='启动', command=self.start_server, bootstyle=SUCCESS).pack(side='left', padx=5)

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

    def browse_dir(self):
        path = tk.filedialog.askdirectory(title='选择图片根目录')
        if path:
            self.dir_var.set(path)

    def start_server(self):
        port = self.port_var.get()
        root = self.dir_var.get()
        if not Path(root).is_dir():
            ttk.dialogs.Messagebox.show_error('目录不存在！', '错误')
            return
        # 写入配置
        with SessionLocal() as session:
            set_root_dir(session, root)
        self.log('服务启动中 ...')
        threading.Thread(target=self.run_server, args=(port, root), daemon=True).start()

    def run_server(self, port, root):
        try:
            global ROOT_DIR
            ROOT_DIR = root
            os.environ['ROOT_DIR'] = root

            for log_name in ['uvicorn', 'uvicorn.error', 'uvicorn.access', 'scanner']:
                lg = logging.getLogger(log_name)
                lg.handlers.clear()  # 删掉控制台
                lg.propagate = False  # 禁止向根logger传递
                lg.addHandler(GuiLogger(self.log_text))

            root_logger = logging.getLogger()
            root_logger.handlers.clear()
            root_logger.addHandler(GuiLogger(self.log_text))

            self.log('服务启动成功', level=logging.INFO)
            uvicorn.run(app, host='0.0.0.0', port=port, log_config=None)
        except Exception as e:
            self.log(f'动失败: {e}', level=logging.ERROR)

    def poll_log(self):
        self.after(100, self.poll_log)

    def log(self, msg, level=logging.INFO):
        self.logger.log(level, msg)


if __name__ == '__main__':
    root = ServerGUI()
    root.mainloop()