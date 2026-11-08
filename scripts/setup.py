#!/usr/bin/env python3
"""Install an isolated Python environment and, for Earth History, its native client."""
import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import venv
import zipfile
from pathlib import Path

PACKAGES = ['requests', 'Pillow', 'pyproj', 'Shapely', 'rasterio', 'certifi']
ROOT = Path(__file__).resolve().parents[1]
EARTH = ROOT.name == 'google-earth-history' or (ROOT / 'scripts/Invoke-EarthHistory.ps1').exists()

def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)

def fetch(url, path, asset=False):
    # curl uses the OS CA store on common macOS installations. Never disable TLS.
    curl = shutil.which('curl.exe' if os.name == 'nt' else 'curl')
    if curl:
        headers = ['--header', 'Accept: application/octet-stream'] if asset else []
        run([curl, '--fail', '--location', '--connect-timeout', '30', '--max-time', '600', '--retry', '2', *headers, '--output', path, url])
    else:
        request = urllib.request.Request(url, headers={'Accept': 'application/octet-stream'} if asset else {})
        with urllib.request.urlopen(request, timeout=120) as response, path.open('wb') as out:
            shutil.copyfileobj(response, out)

def select_asset(assets, system, machine):
    arch = {'arm64': 'arm64', 'aarch64': 'arm64', 'x86_64': 'x64', 'amd64': 'x64'}.get(machine.lower())
    if system == 'Darwin' and arch:
        suffix = f'-macOS-{arch}.dmg'
    elif system == 'Windows' and arch == 'x64':
        suffix = '-win-x64.zip'
    else:
        raise RuntimeError(f'Unsupported native runtime: {system}/{machine}; no automatic emulation')
    matches = [a for a in assets if a['name'].endswith(suffix)]
    if len(matches) != 1:
        raise RuntimeError(f'Expected exactly one release asset ending {suffix}')
    return matches[0]

def native_runtime(destination, release):
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='earth-runtime-') as tmp:
        tmp = Path(tmp)
        metadata = tmp / 'release.json'
        fetch(f'https://api.github.com/repos/Mbucari/GEHistoricalImagery/releases/tags/{release}', metadata)
        asset = select_asset(json.loads(metadata.read_text())['assets'], platform.system(), platform.machine())
        digest = asset.get('digest', '')
        if not digest.startswith('sha256:'):
            raise RuntimeError('Release has no SHA-256 digest; refusing unverified runtime')
        runtime = destination / release
        marker = runtime / 'installed.json'
        if marker.exists():
            record = json.loads(marker.read_text())
            executable = Path(record['executable'])
            if record.get('sha256') != digest[7:] or not executable.is_file():
                raise RuntimeError('Existing runtime does not match release; choose a new --runtime-root')
            run([executable, '--help'], stdout=subprocess.DEVNULL)
            return executable
        if runtime.exists():
            raise RuntimeError(f'Incomplete/existing runtime: {runtime}; choose a new --runtime-root')
        archive = tmp / asset['name']
        fetch(asset['url'], archive, asset=True)
        actual = hashlib.sha256(archive.read_bytes()).hexdigest()
        if actual != digest[7:]:
            raise RuntimeError('Release SHA-256 mismatch')
        stage = tmp / 'extracted'
        stage.mkdir()
        if platform.system() == 'Darwin':
            mount = tmp / 'mounted'
            run(['hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mount, archive])
            try:
                # Preserve the relative dylib/data layout shipped by upstream.
                for item in mount.iterdir():
                    if item.is_symlink():
                        # Ignore /Applications shortcuts; keep bundled relative libraries.
                        if not item.resolve().is_relative_to(mount.resolve()):
                            continue
                        (stage / item.name).symlink_to(os.readlink(item))
                    elif item.is_dir():
                        shutil.copytree(item, stage / item.name, symlinks=True)
                    elif item.is_file() and not item.is_symlink():
                        shutil.copy2(item, stage / item.name)
            finally:
                run(['hdiutil', 'detach', mount])
            name = 'GEHistoricalImagery'
        else:
            with zipfile.ZipFile(archive) as z:
                for item in z.infolist():
                    target = (stage / item.filename).resolve()
                    if not target.is_relative_to(stage.resolve()):
                        raise RuntimeError('Unsafe path in release archive')
                z.extractall(stage)
            name = 'GEHistoricalImagery.exe'
        candidates = list(stage.rglob(name))
        if len(candidates) != 1:
            raise RuntimeError(f'Expected one {name}, found {len(candidates)}')
        relative = candidates[0].relative_to(stage)
        if os.name != 'nt':
            candidates[0].chmod(candidates[0].stat().st_mode | 0o100)
        run([candidates[0], '--help'], stdout=subprocess.DEVNULL)
        shutil.copytree(stage, runtime, symlinks=True)
        executable = runtime / relative
        marker.write_text(json.dumps({'executable': str(executable), 'sha256': actual}, indent=2))
        return executable

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--env', type=Path, default=ROOT / '.venv')
    p.add_argument('--runtime-root', type=Path, default=ROOT / '.runtime')
    p.add_argument('--release', default='v0.7.1')
    p.add_argument('--client', type=Path, help='Reuse an existing compatible Earth History executable')
    p.add_argument('--ca-bundle', type=Path, help='Trusted CA bundle if the system Python lacks a CA store')
    p.add_argument('--plan', action='store_true', help='Print setup plan without writing or downloading')
    a = p.parse_args()
    if sys.version_info < (3, 10):
        p.error('Python 3.10 or newer is required')
    if platform.system() not in ('Darwin', 'Windows'):
        p.error('This installer supports Windows and macOS')
    env = a.env.expanduser().resolve()
    if a.plan:
        print(json.dumps({'environment': str(env), 'packages': PACKAGES, 'native_client': EARTH,
                          'platform': platform.system(), 'architecture': platform.machine()}, indent=2))
        return
    if not env.exists():
        venv.EnvBuilder(with_pip=True).create(env)
    if not (env / 'pyvenv.cfg').is_file():
        p.error('--env must be a Python virtual environment, not an arbitrary directory')
    python = env / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    args = [python, '-m', 'pip', 'install', '--no-cache-dir', '--only-binary=:all:', *PACKAGES]
    if a.ca_bundle:
        args.extend(['--cert', a.ca_bundle.expanduser().resolve()])
    # Python.org installations on macOS can lack a usable CA store. Bootstrap
    # a current Mozilla bundle over curl's OS-validated HTTPS, never insecure TLS.
    if not a.ca_bundle and shutil.which('curl.exe' if os.name == 'nt' else 'curl'):
        with tempfile.TemporaryDirectory(prefix='geo-setup-ca-') as tmp:
            ca = Path(tmp) / 'cacert.pem'
            fetch('https://curl.se/ca/cacert.pem', ca)
            if 'BEGIN CERTIFICATE' not in ca.read_text():
                raise RuntimeError('CA download is not a PEM certificate bundle')
            run([*args, '--cert', ca])
    else:
        run(args)
    # Verify actual raster IO, not only imports; all files are temporary.
    probe = '''import tempfile, pathlib, numpy as np, rasterio, requests, PIL, pyproj, shapely, certifi
from rasterio.transform import from_origin
with tempfile.TemporaryDirectory() as t:
 p=pathlib.Path(t)/'probe.tif'
 with rasterio.open(p,'w',driver='GTiff',width=2,height=2,count=3,dtype='uint8',crs='EPSG:4326',transform=from_origin(10,10,1,1)) as f: f.write(np.ones((3,2,2),dtype='uint8'))
 with rasterio.open(p) as f: assert f.crs.to_epsg()==4326 and f.read().sum()==12
print('Python dependencies and GeoTIFF IO passed')'''
    run([python, '-c', probe])
    result = {'python': str(python), 'platform': platform.system(), 'architecture': platform.machine()}
    if EARTH:
        client = a.client.expanduser().resolve() if a.client else native_runtime(a.runtime_root.expanduser().resolve(), a.release)
        run([client, '--help'], stdout=subprocess.DEVNULL)
        result['executable'] = str(client)
    config = ROOT / 'local-runtime.json'
    temp = config.with_suffix('.tmp')
    temp.write_text(json.dumps(result, indent=2) + '\n')
    temp.replace(config)
    print(json.dumps({'status': 'passed', 'runtime_config': str(config), **result}, indent=2))

if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as e:
        print(f'Setup failed: {e}', file=sys.stderr)
        raise SystemExit(1)
