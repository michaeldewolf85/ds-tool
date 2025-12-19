# ds-tool
A REPL for interacting with various "famous" [data structures](https://opendatastructures.org/). It 
is written in x86-64 assembly and strives for elegance and minimalism.

## Toolchain
All of the examples were handwritten (in vim), compiled (using make) and tested in an Alpine Linux 
VM bootstrapped using `qemu-system` on my Debian PC.

### Virtual machine
The Alpine linux VM was bootstrapped using the following command. Note that to use a different 
`.iso` simply replace the URL in that directive. Note that it is recommended to create the disk 
image somewhere safe _outside_ of this repository's directory in case a fileshare is configured.
```
qemu-img create ../alpine.img 30G

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -m 4G \
  -smp 2 \
  -drive file=../alpine.img,format=raw,cache=none \
  -cdrom https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.2-x86_64.iso \
  -boot order=d \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -nographic
```
Afterwards, a basic installation was performed (e.g. disk install, setting up a user) using 
`setup-alpine`. For the most part, the default answers for the prompts should be fine. Add a user 
named `dev` when prompted. For disk setup choose `sys` and use the `sda` block device. Overall, 
this takes approximately 30 seconds. 

Once Alpine add the dev user to the `wheel` group so that we can use that user to complete the 
setup. Power off the VM when complete
```
echo 'permit :wheel' > /etc/doas.d/doas.conf
adduser dev wheel
poweroff
```

### Booting into the VM
Once the VM has been provisioned you can boot into it without the `boot` and `cdrom` directives. 
The boot command below also enables a file share for this directory and opens port 2222 for SSH (in 
case it might be useful to have multiple login sessions open):
```
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -m 4G \
  -smp 2 \
  -drive file=../alpine.img,format=raw,cache=none \
  -device virtio-net-pci,netdev=net0 \
  -fsdev local,id=fsdev0,security_model=passthrough,path=. \
  -device virtio-9p-pci,fsdev=fsdev0,mount_tag=share \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -nographic
```
From now on we will log in as the `dev` user and finish the setup using `doas` when necessary.

You'll need to manually mount the file share each time you boot (if so desired):
```
mkdir -p ~/ds-tool
doas mount -t 9p share /home/mike/share
```

To SSH into the VM from another tab use the following (assumes `localhost` was specified as the 
hostname during setup):
```
ssh -p 2222 dev@localhost
```
In case the terminal window is doing weird stuff (like getting cut-off) simply run `resize` at the 
shell.

#### One-time setup
The steps below should only need to be executed once:
1. Add colors to the shell:
```
echo 'export TERM=xterm-256color' >> ~/.profile
```
2. Perform a system update and upgrade:
```
doas apk update && doas apk upgrade
```
3. Add some basic packages:
```
doas apk add gcc gdb git make vim
```
4. Enable project local `.vimrc`:
```
echo "set exrc" >> ~/.vimrc
```
