"""Stage Peggle for Hailstone and build a portable release."""

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hailstone", type=Path, required=True, help="path to the Hailstone client checkout")
    parser.add_argument("--version", required=True, help="add-on release version")
    args = parser.parse_args()

    packager = args.hailstone.resolve() / "tools" / "make_addon.py"
    if not packager.is_file():
        parser.error(f"Hailstone packager not found at {packager}")

    with tempfile.TemporaryDirectory(prefix="pegworks-package-") as folder:
        stage = Path(folder)
        shutil.copytree(root / "addon", stage, dirs_exist_ok=True)
        shutil.copy2(root / "LICENSE", stage / "LICENSE")
        subprocess.run(
            [
                sys.executable, str(packager),
                "--name", "pegworks", "--kind", "script", "--version", args.version,
                "--min-client", "0.7.2-beta", "--author", "fryguy503",
                "--description", "Peggle for Hailstone. Twelve original boards, local records, and friend duels.",
                "--caps", "commands,ui,chat,events", "--autoload",
                "--dir", str(stage), "--out", str(root / "dist"),
            ],
            check=True,
        )


if __name__ == "__main__":
    main()
