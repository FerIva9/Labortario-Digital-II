"""Protocolo ASCII emitido por Semana1/fluxo_dados.v."""
from dataclasses import dataclass
import re


@dataclass(frozen=True)
class Event:
    story: int
    character: int


def parse_line(data: bytes) -> Event:
    match = re.fullmatch(rb"H([0-3]),P([0-5])\r?\n", data)
    if match is None:
        raise ValueError(f"Mensagem inválida: {data!r}. Esperado H0,P0 + LF.")
    return Event(int(match[1]), int(match[2]))


class Decoder:
    """Reagrupa leituras parciais; descarta quadros excessivos até o próximo LF."""

    def __init__(self):
        self.buffer = bytearray()
        self.discarding = False

    def feed(self, data: bytes):
        results = []
        for value in data:
            if self.discarding:
                if value == 10:
                    self.discarding = False
                continue
            self.buffer.append(value)
            if value == 10:
                try:
                    results.append(parse_line(bytes(self.buffer)))
                except ValueError as error:
                    results.append(error)
                self.buffer.clear()
            elif len(self.buffer) > 64:
                self.buffer.clear()
                self.discarding = True
                results.append(ValueError("Quadro excedeu 64 bytes; aguardando LF."))
        return results
