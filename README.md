# Wrapped Lyra Options

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://docs.clober.io/)
[![codecov](https://codecov.io/gh/clober-dex/options/branch/dev/graph/badge.svg?token=QNSGDYQOL7)](https://codecov.io/gh/clober-dex/options)
[![CI status](https://github.com/clober-dex/options/actions/workflows/ci.yaml/badge.svg)](https://github.com/clober-dex/options/actions/workflows/ci.yaml)
[![Discord](https://img.shields.io/static/v1?logo=discord&label=discord&message=Join&color=blue)](https://discord.gg/clober)
[![Twitter](https://img.shields.io/static/v1?logo=twitter&label=twitter&message=Follow&color=blue)](https://twitter.com/CloberDEX)

Wrapped Lyra ERC20 contract for Clober DEX in Arbitrum

## Table of Contents

- [Wrapped Lyra](#wrapped-lyra-options)
    - [Table of Contents](#table-of-contents)
    - [Deployments](#deployments)
    - [Install](#install)
    - [Usage](#usage)
        - [Unit Tests](#unit-tests)
        - [Coverage](#coverage)
        - [Linting](#linting)
    - [Licensing](#licensing)

## Deployments

### Deployments By EVM Chain(Arbitrum)

|                         | Address                                                                           |  
|-------------------------|-----------------------------------------------------------------------------------|
| `` | [``]() |

## Install

To install dependencies and compile contracts:

### Prerequisites
- We use [Forge Foundry](https://github.com/foundry-rs/foundry) for test. Follow the [guide](https://github.com/foundry-rs/foundry#installation) to install Foundry.

### Installing From Source

```bash
git clone https://github.com/clober-dex/lyra-wrapper && cd lyra-wrapper
npm install
```

## Usage

### Unit tests
```bash
npm run test
```

### Coverage
To run coverage profile:
```bash
npm run coverage:local
```

To run lint fixes:
```bash
npm run prettier:fix:ts
npm run lint:fix:sol
```

## Licensing

- The primary license for Clober Core is the Time-delayed Open Source Software Licence, see [License file](LICENSE.pdf).
- All files in [`contracts/interfaces`](contracts/interfaces) may also be licensed under GPL-2.0-or-later (as indicated in their SPDX headers), see [LICENSE_AGPL](contracts/interfaces/LICENSE_APGL).
