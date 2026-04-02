# Manual Provisioning Decisions - KijaniKiosk API Server

Date: 2026-04-01
Engineer: Rovenel Abanga

## Decision Documentation Table

| Decision         | Value I chose                                       | Reason                                                        |
| ---------------- | --------------------------------------------------- | ------------------------------------------------------------- |
| Cloud provider   | Google Cloud Platform (GCP)                         | $300 free credit available; e2-micro is permanently free tier |
| Region           | europe-west1 (Belgium)                              | Closest available region to Nairobi; Johannesburg unavailable |
| Zone             | europe-west1-b                                      | Default zone within chosen region                             |
| Operating system | Ubuntu 22.04.5 LTS (jammy)                          | Lab requirement; LTS guarantees security updates until 2027   |
| Instance type    | e2-micro                                            | Smallest free-tier option; sufficient for staging API server  |
| vCPU             | 2 vCPU (shared)                                     | Minimum available on e2-micro                                 |
| RAM              | 958MB                                               | Minimum viable for Node.js staging service                    |
| Root volume size | 10GB standard persistent disk                       | Default size; sufficient for OS and application logs          |
| VPC              | default                                             | Default VPC for europe-west1; provides network isolation      |
| Subnet           | default (europe-west1) — 10.132.0.0/20              | Default subnet assigned automatically by GCP                  |
| Internal IP      | 10.132.0.2                                          | Assigned automatically within subnet range                    |
| External IP      | 34.34.183.186                                       | Ephemeral public IP assigned by GCP for SSH and HTTP access   |
| SSH key pair     | kijanikiosk-key (ed25519)                           | Generated locally; ed25519 is most secure key type available  |
| SSH username     | rovenelabanga2001                                   | GCP derives username from Google account name                 |
| Firewall rule 1  | allow-ssh-kijanikiosk: TCP 22 from 41.90.187.119/32 | Restricts SSH to engineer's IP only; prevents brute force     |
| Firewall rule 2  | allow-http-kijanikiosk: TCP 80 from 0.0.0.0/0       | Allows HTTP traffic from anywhere for web serving             |
| Default deny     | All other inbound traffic denied                    | GCP default policy blocks all traffic not explicitly allowed  |
| Tags/labels      | None applied                                        | Not required for single-instance staging environment          |

## Baseline Server State

### uname -a

Linux kijaniosk-api-server 6.8.0-1048-gcp #51~22.04.1-Ubuntu SMP Wed Feb 11 02:58:49 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

### lsb_release -a

Distributor ID: Ubuntu
Description: Ubuntu 22.04.5 LTS
Release: 22.04
Codename: jammy

### df -h

Filesystem Size Used Avail Use% Mounted on
/dev/root 9.6G 3.0G 6.6G 31% /
tmpfs 480M 0 480M 0% /dev/shm
tmpfs 192M 1.1M 191M 1% /run
tmpfs 5.0M 0 5.0M 0% /run/lock
efivarfs 256K 18K 234K 8% /sys/firmware/efi/efivars
/dev/sda15 105M 6.1M 99M 6% /boot/efi
tmpfs 96M 4.0K 96M 1% /run/user/1002

### free -h

               total   used    free   shared  buff/cache  available

Mem: 958Mi 291Mi 129Mi 1.0Mi 537Mi 518Mi
Swap: 0B 0B 0B

### ip addr show

1: lo: LOOPBACK — 127.0.0.1/8
2: ens4: UP — 10.132.0.2/32 (internal)
External IP: 34.34.183.186

## Notes

- SSH key had to be manually added via browser terminal — GCP did not
  automatically install the locally generated key during instance creation
- Username is derived from Google account (rovenelabanga2001) not the
  standard ubuntu username used on other cloud providers
- Firewall rules are managed separately from the instance in GCP VPC
  Firewall — not inline during instance creation
- No swap space configured — default GCP behaviour for e2-micro
