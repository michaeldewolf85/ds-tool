# ds-tool
A REPL for interacting with various "famous" 
[data structures](https://opendatastructures.org/). It is written in x86-64 
assembly and strives for elegance and minimalism.

## Toolchain
All of the examples were handwritten (in vim), compiled (using make) and tested 
in an Alpine Linux VM bootstrapped using `qemu-system` on my Debian PC.

### Virtual machine
The Alpine linux VM was bootstrapped using the following command. Note that to
use a different `.iso` simply replace the URL in that directive:
```
qemu-img create alpine.img 30G

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -m 4G \
  -smp 2 \
  -drive file=alpine.img,format=raw,cache=none \
  -cdrom https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.2-x86_64.iso \
  -boot order=d \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -nographic
```
Afterwards, a basic installation was performed (e.g. disk install, setting up a
user) using `setup-alpine`. This takes approximately 30 seconds.

TODO: Add an answerfile or some more direction here ...

### Post-installation steps
The only post-installation steps were as follows.

1. Grant my user administrative access:
```
echo 'permit :wheel' > /etc/doas.d/doas.conf
adduser mike wheel
```
2. Add colors to the shell:
```
echo 'export TERM=xterm-256color' >> ~/.profile
```
3. Perform a system update and upgrade:
```
doas apk update && doas apk upgrade
```
4. Add some basic packages:
```
doas apk add gcc gdb git make vim
```
5. Enable project local `.vimrc`:
```
echo "set exrc" >> ~/.vimrc
```

### Booting into the VM
Once the VM has been provisioned you can boot into it without the `boot` and 
`cdrom` directives. This also enables a file share for this directory and opens 
port 2222 for SSH (in case it might be useful to have multiple sessions open):
```
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -m 4G \
  -smp 2 \
  -drive file=alpine.img,format=raw,cache=none \
  -device virtio-net-pci,netdev=net0 \
  -fsdev local,id=fsdev0,security_model=passthrough,path=. \
  -device virtio-9p-pci,fsdev=fsdev0,mount_tag=share \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -nographic
```
Once within the VM you'll need to manually mount the file share (if desired).
```
mkdir -p ~/ds-tool
doas mount -t 9p share /home/mike/share
```
