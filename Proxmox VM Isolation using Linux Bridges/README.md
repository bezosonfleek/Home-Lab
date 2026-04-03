# VM isolation on Proxmox using Linux bridges

> One-Armed Router architecture on a single physical NIC - isolated, NAT-routed environment for virtual machines.

![Proxmox VE](https://img.shields.io/badge/Proxmox_VE-Networking-blue) ![Linux Bridge](https://img.shields.io/badge/Linux-Bridge-green) ![NAT](https://img.shields.io/badge/NAT-iptables-orange)

---

## Contents

1. [Network architecture overview](#1-network-architecture-overview)
2. [Host configuration](#2-host-configuration)
3. [Enabling routing and NAT](#3-enabling-routing-and-nat)
4. [Implementing subnet isolation](#4-implementing-subnet-isolation)
5. [Guest VM configuration](#5-guest-vm-configuration)
6. [Troubleshooting & verification](#6-troubleshooting--verification)

---

## 1. Network architecture overview

Two distinct Linux bridges separate the host's external connectivity from the VM private network.

| Bridge | Role | Details |
|--------|------|---------|
| `vmbr0` | WAN · External | Bridged to physical NIC (`nic0` / `wlp2s0`). Host IP: `192.168.0.102`. Default gateway: `192.168.0.1` |
| `vmbr1` | LAN · Internal | Virtual-only bridge - no physical port. VM gateway: `10.10.10.1`. Subnet: `10.10.10.0/24` |

---

## 2. Host configuration

Edit `/etc/network/interfaces` on the Proxmox host:

```
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
```

---

## 3. Enabling routing and NAT

The Proxmox kernel must forward IPv4 packets and masquerade the private `10.10.10.x` range behind the host's public IP.

**Step 1 - Enable IPv4 forwarding:**

```bash
sysctl -w net.ipv4.ip_forward=1
```

> To make this permanent, add `net.ipv4.ip_forward=1` to `/etc/sysctl.conf`.

**Step 2 - Apply the NAT masquerade rule:**

```bash
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o vmbr0 -j MASQUERADE
```

---

## 4. Implementing subnet isolation

By default, the host will route between the VM and the local `192.168.0.x` network. Use iptables to enforce isolation while keeping internet access intact.

**Block VM access to the local LAN:**

```bash
iptables -I FORWARD -s 10.10.10.0/24 -d 192.168.0.0/24 -j REJECT
```

**Allow access to a specific host (optional):**

```bash
iptables -I FORWARD -s 10.10.10.0/24 -d 192.168.0.50 -j ACCEPT
```

> **Note:** Insert the `ACCEPT` rule *before* the `REJECT` rule - iptables evaluates rules in order, top to bottom.

---

## 5. Guest VM configuration

Configure the guest's network settings to use the internal bridge as its exit path (shown here for Linux Mint / any Debian-based guest).

| Setting | Value |
|---------|-------|
| IP address | `10.10.10.2` (any address in `10.10.10.0/24`) |
| Netmask | `255.255.255.0` |
| Gateway | `10.10.10.1` |
| DNS | `8.8.8.8` or `1.1.1.1` |

> Public DNS servers are required if your local DNS resolver is blocked by the isolation rules.

---

## 6. Troubleshooting & verification

Run these checks to verify the setup is working as expected.

| Test | Command | From | Expected |
|------|---------|------|----------|
| Host internet | `ping 8.8.8.8` | Host | ✅ Should pass |
| VM → host | `ping 10.10.10.1` | Guest VM | ✅ Should pass |
| VM internet | `ping 8.8.8.8` | Guest VM | ✅ Should pass |
| VM isolation | `ping 192.168.0.1` | Guest VM | ❌ Should fail (if isolated) |
