import tkinter as tk
from tkinter import filedialog, messagebox
import ttkbootstrap as ttk
from ttkbootstrap.constants import *
import threading
from pathlib import Path
import logging
from core.config import config
from core.logger import GuiLogger, setup_logger
from server.app import app
import uvicorn


class ServerGUI(ttk.Window):
    def __init__(self):
        super().__init__(title='图片管理服务端', themename='darkly', size=(940, 600))
        self.config = config
        self.logger = setup_logger("server_gui")
        self.server = None
        self.server_thread = None

        self.log_text = None
        self.dir_var = None
        self.port_var = None

        self.build_ui()
        self.after(100, self.poll_log)

    def build_ui(self):
        # 顶部配置栏
        top = ttk.Frame(self)
        top.pack(fill='x', padx=10, pady=10)

        ttk.Label(top, text='端口:').pack(side='left', padx=5)
        self.port_var = tk.IntVar(value=self.config.port)
        self.port_var.trace_add('write', self._save_port)
        ttk.Spinbox(top, from_=1024, to=65535, textvariable=self.port_var, width=6).pack(side='left', padx=5)

        ttk.Label(top, text='根目录:').pack(side='left', padx=5)
        self.dir_var = tk.StringVar(value=self.config.root_dir)
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

        # 绑定日志到GUI
        self.logger.addHandler(GuiLogger(self.log_text))

    def _save_port(self, *args):
        # 保存端口配置
        new_port = self.port_var.get()
        self.config.save_port(new_port)
        # 如果服务器正在运行，提示需要重启
        if self.server:
            self.log(f'>>> 端口已修改为 {new_port}，请重启服务器使配置生效', logging.WARNING)

    def _save_dir(self, *args):
        # 保存目录配置
        new_dir = self.dir_var.get()
        self.config.save_root_dir(new_dir)
        # 如果服务器正在运行，提示需要重启
        if self.server:
            self.log(f'>>> 根目录已修改为 {new_dir}，请重启服务器使配置生效', logging.WARNING)

    def browse_dir(self):
        path = filedialog.askdirectory(title='选择图片根目录')
        if path:
            self.dir_var.set(path)

    def start_server(self):
        # 检查服务器是否已在运行
        if self.server:
            self.log('>>> 服务器已在运行中', logging.WARNING)
            return

        # 获取最新的配置值
        port = self.port_var.get()
        root = self.dir_var.get()

        # 验证目录
        if not Path(root).is_dir():
            messagebox.showerror('错误', '目录不存在！')
            return

        # 保存配置
        self.config.save_root_dir(root)
        self.config.save_port(port)

        # 检查目录有效性
        if not self.config.check_root_dir():
            self.log('目录检查失败，请选择正确的根目录', logging.ERROR)
            return

        self.log(f'>>> 服务启动中，端口: {port}, 根目录: {root}')
        # 启动服务器线程
        self.server_thread = threading.Thread(
            target=self._run_server,
            args=('0.0.0.0', port),
            daemon=True
        )
        self.server_thread.start()

    def _run_server(self, host, port):
        # 使用最新的配置启动服务器
        config = uvicorn.Config(app, host=host, port=port, log_config=None)
        self.server = uvicorn.Server(config)
        self.server.run()

    def stop_server(self):
        if self.server:
            self.server.should_exit = True
            self.server = None
            self.log('>>> 服务已停止', logging.INFO)
        else:
            self.log('>>> 服务未运行', logging.WARNING)

    def poll_log(self):
        self.after(100, self.poll_log)

    def log(self, msg, level=logging.INFO):
        self.logger.log(level, msg)
