from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class Severity(Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"


@dataclass(frozen=True)
class Diagnostic:
    severity: Severity
    message: str
    source: str | None = None

    def __str__(self) -> str:
        prefix = f"[{self.severity.value}]"
        if self.source:
            prefix += f" {self.source}:"
        return f"{prefix} {self.message}"


class DiagnosticCollector:
    def __init__(self) -> None:
        self._diagnostics: list[Diagnostic] = []

    def info(self, message: str, source: str | None = None) -> None:
        self._diagnostics.append(Diagnostic(Severity.INFO, message, source))

    def warning(self, message: str, source: str | None = None) -> None:
        self._diagnostics.append(Diagnostic(Severity.WARNING, message, source))

    def error(self, message: str, source: str | None = None) -> None:
        self._diagnostics.append(Diagnostic(Severity.ERROR, message, source))

    def extend(self, other: "DiagnosticCollector") -> None:
        self._diagnostics.extend(other._diagnostics)

    @property
    def all(self) -> list[Diagnostic]:
        return list(self._diagnostics)

    def of(self, severity: Severity) -> list[Diagnostic]:
        return [d for d in self._diagnostics if d.severity is severity]

    def has_errors(self) -> bool:
        return any(d.severity is Severity.ERROR for d in self._diagnostics)

    def __len__(self) -> int:
        return len(self._diagnostics)

    def __iter__(self):
        return iter(self._diagnostics)
