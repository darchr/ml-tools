# Swap

For some timing experiments, we reduce the amount of DRAM available to the docker container,
and instead allow it to use swap on an Optane drive. This is initially for exploration of
how decreasing memory affects performace of CPU training. Below is outlined the process
of setting up and removing swap partitions.

## Partitioning the Drive

First, I created a partition on the NVM drive with

```sh
sudo fdisk /dev/nvme0n1
```
Then proceeded with the options: 

* `n` (new partition) 
* `p` (primary partiton)
* `1` (partition number)
* Default sectors
* `w` (write this information to disk)

The output of `fdisk` looked like below

```
Welcome to fdisk (util-linux 2.31.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS disklabel with disk identifier 0xe142f7ae.

Command (m for help): n
Partition type
   p   primary (0 primary, 0 extended, 4 free)
   e   extended (container for logical partitions)
Select (default p): p
Partition number (1-4, default 1): 1
First sector (2048-1875385007, default 2048):
Last sector, +sectors or +size{K,M,G,T,P} (2048-1875385007, default 1875385007):

Created a new partition 1 of type 'Linux' and of size 894.3 GiB.

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
```

Running `lsblk` revealed the following now for the NVM drive
```
nvme0n1     259:0    0 894.3G  0 disk
└─nvme0n1p1 259:2    0 894.3G  0 part
```

## Creating a file system and mounting

Then, I created a file system on the drive with
```sh
sudo mkfs -t ext4 /dev/nvme0n1p1
```
I created a directory and mounted the drive:
```sh
sudo mkdir /mnt/nvme
sudo mount /dev/nvme0n1p1 /mnt/nvme
```

## Configuring Swap

```sh
sudo fallocate -l 32g /mnt/nvme/32gb.swap
sudo chmod 0600 /mnt/nvme/32gb.swap
sudo mkswap /mnt/nvme/32gb.swap
sudo swapon -p 0 /mnt/nvme/32gb.swap
```
Verify that the file is being used as swap using
```sh
swapon -s
```

## Removing Swap

To remove the swapfile from system swap, just use
```sh
sudo swapoff /mnt/nvme/32gb.swap
```
