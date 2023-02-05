#!/usr/bin/env python
import subprocess
from typing import List
import os
import sys
from pathlib import Path
import logging
import time
from argparse import ArgumentParser

REQUIRED = ["git"]
INSTALL = ["zsh"]
HERE = Path(os.path.realpath(__file__)).parent
BINARY2PACKAGE = {
    'git': 'git',
    'zsh': 'zsh',
}

def run(*args, **kwargs):
    p = subprocess.run(*args, **kwargs)
    p.check_returncode()
    return p

def fail(msg, code=1):
    logging.error(msg)
    sys.exit(code)

def create_parser() -> ArgumentParser:
    parser = ArgumentParser(
            prog = sys.argv[0],
            description = "Install script for terminal environment"
            )
    parser.add_argument("--packages", action='store_true', help="Also install packages (from apt)")
    return parser

def query_yes_no(question, default=True) -> bool:
    """Ask a yes/no question via input() and return their answer.

    "question" is a string that is presented to the user.
    "default" determines whether to presume yes or no if the user just hits <Enter>.
        It can also be none for no default.

    The "answer" return value is True for "yes" or False for "no".

    Credit: https://stackoverflow.com/questions/3041986/apt-command-line-interface-like-yes-no-input
    """
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if defaultY is None:
        prompt = "[y/n]"
    elif default:
        prompt = "[Y/n]"
    else:
        prompt = "[y/N]"

    while True:
        choice = input(f"{question} {prompt} ").lower()
        if default is not None and choice == "":
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            print("Please respond with 'yes' or 'no' " "(or 'y' or 'n').")

def backup(path: Path):
    if path.exists() and not path.is_symlink():
        now = int(time.time())
        newname = f"{path.name}.bak-{now}"
        newpath = path.parent / newname
        os.rename(path, newpath)
        logging.info(f"Renamed {path} -> {newpath}")

def ensure_link(target: Path, link_name: Path):
    if link_name.exists():
        if link_name.samefile(target):
            logging.info(f"Link {link_name} -> {target} already exists")
            return
        backup(link_name)
    link_name.symlink_to(target)
    logging.info(f"Installed symlink {link_name} -> {target}")


def main():
    if os.getuid() == 0:
        fail("Do not run as root")
    missing_dependencies = missing_pkgs(REQUIRED)
    if missing_dependencies:
        fail(f"Missing the following dependencies in PATH: {missing_dependencies}")

    logging.basicConfig(level=logging.INFO)

    args = create_parser().parse_args()

    if args.packages:
        install_packages()
    setup_zsh()
    setup_ssh()
    setup_dotconfig()

def missing_pkgs(dependencies: List[str]) -> List[str]:
    failures = list()
    for dependency in dependencies:
        p = subprocess.run(["which", dependency], capture_output=True)
        if p.returncode != 0:
            failures.add(dependency)
    return failures

def apt_update():
    run(["sudo", "apt-get", "update"])

def apt_install(pkgs):
    if not isinstance(pkgs, list):
        pkgs = [pkgs]
    logging.info(f"Installing the following packages: {pkgs}")
    run(["sudo", "apt-get", "install", *pkgs])

def install_packages():
    missing = missing_pkgs(INSTALL)
    if missing:
        logging.info(f"Will install the following packages: {missing}")
        apt_update()
        apt_install(missing)
    else:
        logging.info("Nothing to install")


def setup_zsh():
    """Sets up everything related to zsh
    1) Symlinks .zshrc
    2) Clones oh-my-zsh
    """
    terminalenv_zshrc = HERE / "zsh/.zshrc"
    zshrc = Path.home() / ".zshrc"
    ensure_link(terminalenv_zshrc, zshrc)
    omz = Path.home() / '.oh-my-zsh' 
    if omz.exists():
        logging.info(f"{omz} already exists. Not installing")
    else:
        os.umask(0o022)
        logging.info("Cloning oh-my-zsh")
        run(["git", "clone", "https://github.com/ohmyzsh/ohmyzsh.git", f"{omz}"])

    
def setup_ssh():
    """Installs a link in ~/.ssh/config"""

    ssh_folder = Path.home() / ".ssh"
    ssh_config = ssh_folder / "config"
    terminalenv_ssh_config = HERE / "ssh/config"
    ensure_link(terminalenv_ssh_config, ssh_config)

def setup_dotconfig():
    """For each directory in terminalenv/config, makes a symlink with the same name in ~/.config"""

    cfg_dir = HERE / "config"
    dotcfg = Path.home() / ".config"

    for d in cfg_dir.iterdir():
        if not d.is_dir():
            continue
        link_name = dotcfg / d.name
        ensure_link(d, link_name)


if __name__ == "__main__":
    main()
