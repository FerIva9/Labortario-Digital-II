"""Configuração de DPI antes de criar qualquer janela Tk no Windows."""
import sys


def configure_display():
    if sys.platform == 'win32':
        import ctypes
        # O .exe declara essa configuração no manifesto. Ao executar o código
        # diretamente, usa a escala do sistema; Tk calcula o tamanho das fontes.
        try:
            ctypes.windll.user32.SetProcessDPIAware()
        except (AttributeError, OSError):
            pass
