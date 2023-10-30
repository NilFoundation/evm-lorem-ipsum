# Lorem Ipsum: zkOracle bringing L1s/L2s, Beacon Chain or Ethereum Historical Data to Ethereum.

[![Discord](https://img.shields.io/discord/969303013749579846.svg?logo=discord&style=flat-square)](https://discord.gg/KmTAEjbmM3)
[![Telegram](https://img.shields.io/badge/Telegram-2CA5E0?style=flat-square&logo=telegram&logoColor=dark)](https://t.me/nilfoundation)
[![Twitter](https://img.shields.io/twitter/follow/nil_foundation)](https://twitter.com/nil_foundation)

----------------------------
### Project architecture

* Oracle -- entry point that provides API for initiation cross-chain send request. Also, it handles response data with the target contract. The current implementation supports prior verification of the destination chain verification (destination smartcontract).
* Transition manager -- is the middle layer responsible for the light client state update on the receiver side and proof request handling on the sender side.
* AMB -- sends/recive crosschain raw data.

On the picture below is the overall design of the contracts:
![design](./figures/LoremIpsum.jpg)
----------------------------
### How to
When all needed tools are installed:
- npm >= 8.19.0
- hardhat >= 2.14.0
- node >= 16.20.0

Make sure you have SSH token for GitHub and the use:
```
git clone git@github.com:NilFoundation/evm-lorem-ipsum.git --recursive
cd evm-lorem-ipsum
npx hardhat compile
npx hardhat test
```
----------------------------
## Any questions?
Fill free to reach out:
@Zontec -- Ilya Marozau (ilya.marozau@nil.foundation)
@SK0M0R0H -- Ilia Shirobokov (i.shirobokov@nil.foundation)
