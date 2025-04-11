zip -9 -r sokoadventure.love data lib src main.lua conf.lua
mv sokoadventure.love ~/love2d-build/
cd ~/love2d-build
./love-11.5-x86_64.AppImage --appimage-extract
cat squashfs-root/bin/love sokoadventure.love > squashfs-root/bin/sokoadventure
chmod +x squashfs-root/bin/sokoadventure
rm squashfs-root/bin/love
rm squashfs-root/love.svg
cp ~/Projects/sokoadventure-love/release/AppRun squashfs-root/
cp ~/Projects/sokoadventure-love/release/sokoadventure.desktop squashfs-root/
cp ~/Projects/sokoadventure-love/release/sokoadventure.svg squashfs-root/
./appimagetool-x86_64.AppImage squashfs-root sokoadventure.AppImage
rm -r squashfs-root
rm sokoadventure.love
mv sokoadventure.AppImage ~/Projects/sokoadventure-love/release/
