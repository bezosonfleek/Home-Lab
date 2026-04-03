Proxmox VE
Networking
Linux Bridge
NAT / iptables
VM isolation on Proxmox using Linux bridges
One-Armed Router architecture on a single physical NIC — isolated, NAT-routed environment for virtual machines.

Contents
1Network architecture overview
2Host configuration
3Enabling routing and NAT
4Implementing subnet isolation
5Guest VM configuration
6Troubleshooting & verification
1. Network architecture overview
Two distinct Linux bridges separate the host's external connectivity from the VM private network.

WAN · External
vmbr0
Bridged to the physical NIC (nic0 / wlp2s0)
Host IP: 192.168.0.102
Default gateway: 192.168.0.1
LAN · Internal
vmbr1
Virtual-only bridge — no physical port
VM gateway: 10.10.10.1
Subnet: 10.10.10.0/24
2. Host configuration
Edit /etc/network/interfaces on the Proxmox host:

auto lo
iface lo inet loopback

# External bridge (connected to physical router)
auto vmbr0
iface vmbr0 inet static
    address 192.168.0.102/24
    gateway 192.168.0.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0

# Internal isolated bridge (VM gateway)
auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
3. Enabling routing and NAT
The Proxmox kernel must forward IPv4 packets and masquerade the private 10.10.10.x range behind the host's public IP.

1
Enable IPv4 forwarding:

sysctl -w net.ipv4.ip_forward=1
To make this permanent, add net.ipv4.ip_forward=1 to /etc/sysctl.conf.
2
Apply the NAT masquerade rule:

iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o vmbr0 -j MASQUERADE
4. Implementing subnet isolation
By default, the host will route between the VM and the local 192.168.0.x network. Use iptables to enforce isolation while keeping internet access intact.

Block VM access to the local LAN
iptables -I FORWARD -s 10.10.10.0/24 -d 192.168.0.0/24 -j REJECT
Allow access to a specific host (optional)
iptables -I FORWARD -s 10.10.10.0/24 -d 192.168.0.50 -j ACCEPT
Insert the ACCEPT rule before the REJECT rule — iptables evaluates rules in order, top to bottom.
5. Guest VM configuration
Configure the guest's network settings to use the internal bridge as its exit path (shown here for Linux Mint / any Debian-based guest).

Setting	Value
IP address	10.10.10.2 (any in 10.10.10.0/24)
Netmask	255.255.255.0
Gateway	10.10.10.1
DNS	8.8.8.8 or 1.1.1.1
Public DNS servers are required if your local DNS resolver is blocked by the isolation rules.
6. Troubleshooting & verification
Run these checks to verify the setup is working as expected.

Test	Command	From	Expected
Host internet	ping 8.8.8.8	Host	
Should pass
VM → host	ping 10.10.10.1	Guest VM	
Should pass
VM internet	ping 8.8.8.8	Guest VM	
Should pass
VM isolation	ping 192.168.0.1	Guest VM	
Should fail (if isolated)
