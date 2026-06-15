#  𝕝c  ℍelp
### (openwrt system) Use the 〖lc〗 command to simplify querying the router connection table
#### (win10 system) Use the 〖lc〗 command to support multiple windows searching simultaneously

#### 【lc】 Command:
##### 『 L = list 』『 C = conect 』『 Connection List = List of connections 』


#### Create Command Alias:
```css
ln -s /etc/storage/lc.sh /usr/bin/lc
```
#### (win10 additional) Create aliases (Cygwin64 Terminal):
```css
ln -s "D:\\path to your file\\bmd.txt" "/etc/storage/bmd.txt"
ln -s "D:\\path to your file\\bmd6.txt" "/etc/storage/bmd6.txt"
ln -s /mnt/c/Users/Administrator/Desktop/nf_conntrack.log /home/Administrator/nf_conntrack.log
```
#### Verify Installation:
```css
cat /etc/storage/bmd.txt
```
#### (win10) Add to `G:\Cygwin\home\Administrator\.bashrc`:
```bash
# Use Windows script command
alias lc='lc.cmd'
```

#### Parameters:
- [x] `-L` (letter l: `small`): Parameter content: empty (`null`)
* ###### Example: lc -l or lc -L
> Description: Simplify connection table output ➠ Only保留⏎
>
> Protocol type (ipv4/6), network type (tcp/http?/udp), source IP, source port, destination IP, destination port, packets count, bytes size
---
- [x] `-D` (letter d: `Debug`): Parameter content: empty (`null`)
* ###### Example: lc -d or lc -D
> Description: Print debug information:
>
> Debug: source IP, source port, (max) packets count per line, (max) bytes size per line,
>
> (custom) packets count (if set), (custom) bytes size (if set)
---
- [x] `-I` (letter i: `Internet`): Parameter content: `ipv4`/`ipv6`
* ###### Example: lc -i ipv4 or lc -I ipv6 (case-insensitive)
> Description: View ipv4 or ipv6 connection table
---
- [x] `-4` (number 4): Parameter content: empty (`null`)
* ###### Example: lc -4
> Description: View ipv4 connection table (equivalent to -i ipv4)
---
- [x] `-6` (number 6): Parameter content: empty (`null`)
* ###### Example: lc -6
> Description: View ipv6 connection table (equivalent to -i ipv6)
---
- [x] `-N` (letter n: `Network`): Parameter content: `tcp`/`udp`/`icmp`/`icmpv6`/`esp`/`……`
* ###### Example: lc -n udp or lc -N udp (case-insensitive)
> Description: View udp type connection table
---
- [x] `-p` (lowercase p: `ports`): Parameter content: `2710`,`6969` or `2710:6969`
* ###### Example: lc -p 8888 (lowercase p for displaying ports)
> Description: Only display connection table entries matching custom ports 2710 and 6969
>
> Matches sport+dport, comma-separated for multiple ports
>
> Port range supports `-` or `:` delimiter, e.g. `6811-6924` or `6811:6924`
---
- [x] `-P` (uppercase P: `Ports`): Parameter content: `666`,`888`,`6811-6924` or `6811:6924`
* ###### Example: lc -P 6811-6924 or lc -P 6811:6924 (uppercase P for filtering ports)
> Description: Filter out and hide these ports/port ranges
>
> Matches and filters sport+dport entries containing the specified port numbers
>
> Port range supports `-` or `:` delimiter
---
- [x] `-B` (letter b: `bytes`): Parameter content: `1000000`/`1500000` (any number)
* ###### Example: lc -b 1000000 or lc -B 1000000
> Description: Display entries where (max bytes per line) >= custom bytes parameter
---
- [x] `-S` (letter s: `packets`): Parameter content: `5000`/`10000` (any number)
* ###### Example: lc -s 5000 or lc -S 5000
> Description: Display entries where (max packets per line) >= custom packets parameter
---
- [x] `-ip` (case-insensitive: `ip`): Parameter content: `2001:250:250:a000::2600`/`6.6.6.6`
* ###### Example: lc -ip 6.6.6.6
> Description: Display connection table entries containing the specified IPv4/IPv6 address
>
> Supports subnet search, e.g. 104.234.212.0/24
>
> Search parameter: 104.234.212
>
> Supports IPv6 subnet search, e.g. 2601:fea6:80dd:022c::/64
>
> Search parameter: 2601:fea6:80dd:022c
>
> IPv6 addresses in connection table entries must be displayed as 4-digit segments, so zeros are automatically padded when needed (handled by script)
* ###### Example: lc -ip 2a00:7c80:0:243::2
> Script auto-pads and searches:
>
>       cat /proc/net/nf_conntrack | grep -a "2a00:7c80:0000:0243:0000:0000:0000:0002"
---
- [x] `-ips` (case-insensitive: `ips`): Parameter content: `/etc/storage/bmd.txt` (uses default path when empty)
* ###### Example: lc -ips /etc/storage/bmd.txt
> Description: Filter out and hide entries containing IPs/subnets listed in the file (one per line, leave last line empty)
>
> When encountering subnets in file, automatically extracts usable IP prefix as index
>
> Example: 104.234.212.0/24
>
> Filter index: 104.234.212
>
> Also supports IPv6 address auto-padding and subnet indexing
>
> Example: 2601:fea6:80dd:022c::/64
>
> Filter index: 2601:fea6:80dd:022c
>
> Example: 2a00:7c80:0:243::2
>
> Filter index: 2a00:7c80:0000:0243:0000:0000:0000:0002






##### Project Initiator: rer
##### Project Collaborators: ChatGPT, Doubao, Trae (solo)
