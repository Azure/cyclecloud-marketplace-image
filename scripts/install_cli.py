#!/usr/bin/env python

REQUIRED_PYTHON_VERSION = (3, 6, 0)

import sys

def assert_python_version():
    vi = sys.version_info
    current_version = (vi[0], vi[1], vi[2])
    if current_version < REQUIRED_PYTHON_VERSION:
        sys.stderr.write("CycleCloud requires Python %s.%s.%s or later, found: %s.%s.%s\n" % (REQUIRED_PYTHON_VERSION + current_version))
        sys.stdout.write("Exiting now.\n")
        sys.stderr.flush()
        sys.stdout.flush()
        sys.exit(1)

assert_python_version()


import argparse
import logging
import os
import platform
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
import venv
import zipfile
import glob

_IS_WINDOWS = platform.system().lower().startswith("win")
_IS_OSX = sys.platform == 'darwin'
_IS_LINUX = not _IS_WINDOWS and not _IS_OSX

if _IS_LINUX:
    _AZ_COPY_URL = "https://azcopyvnext.azureedge.net/release20210226/azcopy_linux_amd64_10.9.0.tar.gz"
elif _IS_WINDOWS:
    _AZ_COPY_URL = "https://azcopyvnext.azureedge.net/release20210226/azcopy_windows_amd64_10.9.0.zip"
elif _IS_OSX:
    _AZ_COPY_URL = "https://azcopyvnext.azureedge.net/release20210226/azcopy_darwin_amd64_10.9.0.zip"


def print_now(msg, err=False):
    if err:
        stream = sys.stderr
    else:
        stream = sys.stdout

    stream.write("%s\n" % msg)
    stream.flush()


def do_error(msg, do_exit=True):
    msg = "ERROR: " + msg
    print_now(msg, err=True)
    if do_exit:
        print_now('Exiting now')
        sys.exit(1)


def fetch_azcopy(destination):
    with tempfile.TemporaryDirectory() as temp_dir:
        archive_file = os.path.join(temp_dir, _AZ_COPY_URL.split("/")[-1])
        urllib.request.urlretrieve(_AZ_COPY_URL, archive_file)
        if archive_file.endswith(".tar.gz"):
            with tarfile.open(archive_file, 'r:gz') as f:
                f.extractall(path=temp_dir)
        else:
            with zipfile.ZipFile(archive_file, "r") as f:
                f.extractall(path=temp_dir)
        binaries = glob.glob(os.path.join(temp_dir, "*", "azcopy*"))
        if len(binaries) == 0:
            raise Exception("No azcopy binary found in archive: " + _AZ_COPY_URL)
        elif len(binaries) > 1:
            raise Exception("Multiple azcopy binaries found in archive: " + _AZ_COPY_URL)
        os.chmod(binaries[0], 0o755)
        shutil.move(binaries[0], destination)


def configure_logging(verbose):
    level = logging.WARN
    if verbose:
        level = logging.DEBUG

    logging.basicConfig(level=level)


def assert_can_install_systemwide():
    '''
    Assert that the user is executing this script as root/sudo/admin
    '''

    if _IS_WINDOWS:
        import ctypes
        if not ctypes.windll.shell32.IsUserAnAdmin():
            do_error('You must execute this script as an administrator to use the --system option')
    else:
        if not os.geteuid() == 0:
            do_error('You must execute this script with sudo or as root to use the --system option')


def create_virtualenv(venv_dir, assumeyes):
    if os.path.isfile(venv_dir):
        do_error("The installation directory already occupied by a file.")

    elif os.path.isdir(venv_dir):
        if not assumeyes:
            sys.stdout.write("An existing installation is present at: %s\nAre you sure you want to replace it? [Y/n] " % venv_dir)
            sys.stdout.flush()
            v = sys.stdin.readline().strip()
        else:
            v = "yes"

        if v.lower() in ["", "y", "yes"]:
            shutil.rmtree(venv_dir)
        else:
            print_now("Installation Canceled")
            sys.exit(1)

    parentdir = os.path.dirname(venv_dir)
    if not os.path.exists(parentdir):
        logging.debug('Creating directory %s', parentdir)
        os.makedirs(parentdir)

    print_now('Creating virtual environment...')
    venv.create(venv_dir, with_pip=True)


def get_venv_bin_path(venv_dir):
    # the subdirectory w/ executables varies between windows and everything else
    subdirectory = 'bin'
    if _IS_WINDOWS:
        subdirectory = 'Scripts'

    return os.path.join(venv_dir, subdirectory)


def find_packages(package_dir):
    files = [os.path.join(package_dir, f) for f in os.listdir(package_dir)]
    packages = [p for p in files if os.path.isfile(p)]
    logging.debug('Found packages %s', packages)
    return packages


def install_packages(venv_dir, package_dir):
    venv_bin_dir = get_venv_bin_path(venv_dir)
    pip_path = os.path.join(venv_bin_dir, 'pip')
    install_cmd = [pip_path, 'install', '--upgrade', 'pip']
    logging.debug('Executing command %s', ' '.join(install_cmd))
    p = subprocess.Popen(install_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    _, stderr = p.communicate()
    install_cmd = [pip_path, 'install']
    packages = find_packages(package_dir)
    install_cmd.extend(packages)
    print_now("Installing...")
    logging.debug('Executing command %s', ' '.join(install_cmd))
    p = subprocess.Popen(install_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    _, stderr = p.communicate()
    if p.returncode != 0:
        do_error('Installation of packages failed with stderr: %s' % stderr)
    else:
        logging.debug('Successfully installed packages %s', packages)


def setup_bin_dir(venv_dir, bin_dir, system_install):
    print_now("Creating script references...")
    venv_bin_dir = get_venv_bin_path(venv_dir)
    if not os.path.exists(bin_dir):
        os.makedirs(bin_dir)

    if _IS_WINDOWS:
        copy_script(venv_bin_dir, bin_dir, 'cyclecloud.exe')

        script_path = os.path.join(os.path.dirname(__file__), "update-path.ps1")

        target_env = "Machine" if system_install else "User"

        cmd = 'powershell.exe -file "%s" %s "%s"' % (script_path, target_env, bin_dir)
        subprocess.check_call(cmd, shell=True)

    else:
        link_script(venv_bin_dir, bin_dir, 'cyclecloud')

        if bin_dir not in os.environ['PATH']:
            print_now("'%s' not found in your PATH environment variable. Make sure to update it."
                      % bin_dir, err=True)


def copy_script(venv_bin_dir, bin_dir, executable):
    source = os.path.join(venv_bin_dir, executable)
    target = os.path.join(bin_dir, executable)

    if os.path.exists(target):
        logging.debug('Script %s exists, deleting', target)
        os.remove(target)

    shutil.copyfile(source, target)


def link_script(venv_bin_dir, bin_dir, executable):
    source = os.path.join(venv_bin_dir, executable)
    target = os.path.join(bin_dir, executable)

    if os.path.islink(target):
        logging.debug('Link %s exists, deleting', target)
        os.remove(target)
    elif os.path.exists(target):
        do_error('Path %s exists and is not a symlink, cannot update' % target)

    logging.debug('Symlinking %s to %s', target, source)
    os.symlink(source, target)
    os.chmod(target, 0o755)


def main():
    parser = argparse.ArgumentParser(description='Installs the CycleCloud CLI')
    parser.add_argument('--installdir', default='~/.cycle/cli',
                        help='path to install the cli tools')
    parser.add_argument('--system', action='store_true', default=False,
                        help='install executables so that they are available to all users')
    parser.add_argument('-v', '--verbose', action='store_true', default=False,
                        help='print logging information')
    parser.add_argument('-y', '--assumeyes', action="store_true",
                       help='assume yes for any confirmation prompts')
    args = parser.parse_args()

    configure_logging(args.verbose)

    if args.system:
        assert_can_install_systemwide()
        if _IS_WINDOWS:
            venv_dir = 'C:\\Program Files\\CycleCloud-Cli'
            bin_dir = venv_dir + '\\bin'
        else:
            venv_dir = '/usr/local/cyclecloud-cli'
            bin_dir = '/usr/local/bin'
    else:
        venv_dir = os.path.abspath(os.path.expanduser(args.installdir))
        if _IS_WINDOWS:
            bin_dir = venv_dir + '\\bin'
        else:
            bin_dir = os.path.abspath(os.path.expanduser('~/bin'))

    package_dir = os.path.join(os.path.dirname(__file__), 'packages')

    print_now('Installation Directory: %s' % venv_dir)
    print_now('Scripts Directory: %s' % bin_dir)

    create_virtualenv(venv_dir, args.assumeyes)

    install_packages(venv_dir, package_dir)

    fetch_azcopy(get_venv_bin_path(venv_dir))

    setup_bin_dir(venv_dir, bin_dir, args.system)

    print_now("Installation Complete")


if __name__ == '__main__':
    main()

