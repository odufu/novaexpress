import os
import shutil
import zipfile

build_dir = os.path.abspath('build/web')
htaccess_src = os.path.abspath('web/.htaccess')
htaccess_dest = os.path.join(build_dir, '.htaccess')
index_dest = os.path.join(build_dir, 'index.html')
notfound_dest = os.path.join(build_dir, '404.html')
zip_path = os.path.abspath('novaexpress_web_cpanel.zip')

print(f"Ensuring .htaccess in {htaccess_dest}...")
shutil.copy2(htaccess_src, htaccess_dest)

print(f"Ensuring 404.html fallback from {index_dest} to {notfound_dest}...")
shutil.copy2(index_dest, notfound_dest)

print(f"Creating cPanel deployment archive at {zip_path}...")
count = 0
total_bytes = 0

with zipfile.ZipFile(zip_path, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zipf:
    for root, dirs, files in os.walk(build_dir):
        for file in files:
            full_path = os.path.join(root, file)
            arcname = os.path.relpath(full_path, build_dir)
            zipf.write(full_path, arcname)
            count += 1
            total_bytes += os.path.getsize(full_path)

zip_size_mb = os.path.getsize(zip_path) / (1024 * 1024)
print(f"Successfully packaged {count} files ({total_bytes / (1024 * 1024):.2f} MB uncompressed) into {zip_path} ({zip_size_mb:.2f} MB compressed).")

