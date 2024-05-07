<div id="top"></div>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]
[![Build pass](https://github.com/real-token/reg-ccip-core/actions/workflows/node.js.yml/badge.svg)](https://github.com/real-token/reg-ccip-core/actions/workflows/node.js.yml)
[![Prettier](https://img.shields.io/badge/code_style-prettier-ff69b4.svg?style=flat-square)](https://github.com/prettier/prettier)

<!-- PROJECT LOGO -->
<br />
<div align="center" id="about-the-project">
  <a href="https://github.com/real-token/reg-ccip-core">
    <img src="images/logo.svg" alt="Logo" width="80" height="80">
  </a>

<h3 align="center">RealToken Ecosystem Governance</h3>

  <p align="center">
    REG - CCIP
    <br />
    <a href="https://realt.co/"><strong>Realt.co</strong></a>
    <br />
    <br />
    <a href="https://github.com/real-token/reg-ccip-core/issues">Report Bug</a>
    ·
    <a href="https://github.com/real-token/reg-ccip-core/issues">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#built-with-hardhat">Built With Hardhat</a></li>
  </ol>
</details>

<!-- GETTING STARTED -->

## Getting Started

### Prerequisites

- npm
  ```sh
  npm install npm@latest -g
  ```

### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/real-token/reg-ccip-core.git
   ```
2. Install NPM packages
   ```sh
   npm install
   ```
3. Setup a `.env` file, with the following config

   > CoinMarketCap API Key [here](https://coinmarketcap.com/api/pricing/)

   > Infura API Key [here](https://infura.io/pricing)

   > Etherscan API Key [here](https://etherscan.io/apis)

   > Check [.env.example](.env.example)

4. Check available command

   ```
   npx hardhat --help
   ```

   > Hardhat Getting Started [here](https://hardhat.org/getting-started#running-tasks)

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- ROADMAP -->

## Roadmap

- RealToken Ecosystem Governance ✅
- CCIP (cross-chain) ✅
- Testing ✅
- Static analysis (Slither) ✅
- Audit ✅

See the [open issues](https://github.com/real-token/reg-ccip-core/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->

## Usage

Before running test:

- Go to hardhat.config.ts and change solidity version to 0.8.19 and optimizer run to 10000 times to be able to compile Chainlink contracts.
- We assigned the addresses of LINK and Wrapped native token as constants in the contract for gas optimization. Therefore, before running test, we need to adapt the address of LINK and WrappedNativeToken in the contract to thoses addresses on Hardhat.

```
address private constant \_linkToken =
0x5FC8d32690cc91D4c39d9d3abcBD16989F875707; // LINK on Hardhat
address private constant \_wrappedNativeToken =
0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9; // WETH on Hardhat
```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- COVERAGE -->

## Coverage

```
npx hardhat coverage
```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- GAS FEES -->

## Gas fees

```
npx hardhat test
```

## Deployments

```
- Setup addresses of LINK/WrappedNative in contract
- Set up ADMIN/UPGRADER in .env
- Set up ROUTER in .env for each chain
- Deploy CCIPSenderReceiver on Sepolia
- Deploy CCIPSenderReceiver on Mumbai
- allowlistToken
- allowlistDestinationChain
```

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- AUDIT -->

## Audit

The REG and CCIPSenderReceiver contracts are audited by ABDK. The report can be found [here](./audit/ABDK_RealT_RegCcipCore_v_1_0.pdf).

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- CONTRIBUTING -->

## Contributing

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- CONTACT -->

## Contact

Support - [@RealTPlatform](https://twitter.com/RealTPlatform) - support@realt.co

Project Link: [https://github.com/real-token/reg-ccip-core](https://github.com/real-token/reg-ccip-core)

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- BUILD WITH HARDHAT -->

## Built With Hardhat

- [Eslint](https://eslint.org/)
- [Chai](https://www.chaijs.com/guide/)
- [Solhint](https://github.com/protofire/solhint)
- [Prettier](https://github.com/prettier/prettier)
- [solidity-coverage](https://github.com/sc-forks/solidity-coverage)
- [dotenv](https://www.npmjs.com/package/dotenv)
- [Waffle](https://getwaffle.io/)
- [Typescript](https://www.typescriptlang.org/)

<p align="right">(<a href="#top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->

[contributors-shield]: https://img.shields.io/github/contributors/real-token/reg-ccip-core.svg?style=for-the-badge
[contributors-url]: https://github.com/real-token/reg-ccip-core/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/real-token/reg-ccip-core.svg?style=for-the-badge
[forks-url]: https://github.com/real-token/reg-ccip-core/network/members
[stars-shield]: https://img.shields.io/github/stars/real-token/reg-ccip-core.svg?style=for-the-badge
[stars-url]: https://github.com/real-token/reg-ccip-core/stargazers
[issues-shield]: https://img.shields.io/github/issues/real-token/reg-ccip-core.svg?style=for-the-badge
[issues-url]: https://github.com/real-token/reg-ccip-core/issues
[license-shield]: https://img.shields.io/github/license/real-token/reg-ccip-core.svg?style=for-the-badge
[license-url]: https://github.com/real-token/reg-ccip-core/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://www.linkedin.com/company/realtplatform/
[product-screenshot]: images/screenshot.png
[use-template]: images/delete_me.png
[use-url]: https://github.com/real-token/reg-ccip-core/generate
