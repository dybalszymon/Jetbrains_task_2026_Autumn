"""Run Part 2 (init + load) then Part 3 (transforms) end-to-end."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))

from init_db import main as init_main  # noqa: E402
from transform import main as transform_main  # noqa: E402


def main() -> int:
    rc = init_main()
    if rc != 0:
        return rc
    return transform_main()


if __name__ == "__main__":
    sys.exit(main())
