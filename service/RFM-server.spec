# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['gui_server.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[
        'config',
        'config_ops',
        'database',
        'folder_mtime',
        'main',
        'models',
        'needs_update',
        'scanner',
        'utils',
        ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='RFM-server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
