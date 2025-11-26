# Launch Parameters

## Required
- `--pubkey <PUBKEY>` - Your public key

## GPU
- `--gpu|--g|-g|--devices|--d|-d <numbers>` - GPU selection (comma separated: 0,1,3)

## Network
- `--proxy <PROXY>` - Proxy socket (10.0.0.1:9999)
- `--local-ip <IP>` - Machine LAN IP
- `--region <region>` - Region: eu/us/asia

## Identification
- `--name <NAME>` - Machine identifier
- `--label <LABEL>` - Cluster/group label

## Performance
- `--threads-per-card <N>` - CPU threads per GPU
- `--ts <CPU_CORES>` - CPU affinity mask

## Other
- `-h, --help` - Show help

## Examples
```bash
./nockminer --pubkey 0x123... --gpu 0,1 --proxy 10.0.0.1:9999
./nockminer --pubkey 0x123... --gpu 0-2 --name "Rig1" --region eu
