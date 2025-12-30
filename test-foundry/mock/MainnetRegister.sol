// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title Register Contract
/// @notice This contract allows storing and retrieving network details for various chains.
/// @dev Stores network details in a mapping based on chain IDs.
contract MainnetRegister {
    struct NetworkDetails {
        uint64 chainSelector;
        address routerAddress;
        address linkAddress;
        address wrappedNativeAddress;
        address ccipBnMAddress;
        address ccipLnMAddress;
        address rmnProxyAddress;
        address registryModuleOwnerCustomAddress;
        address tokenAdminRegistryAddress;
    }

    /// @notice Mapping to store network details based on chain ID.
    mapping(uint256 chainId => NetworkDetails) internal s_networkDetails;

    /// @notice Constructor to initialize the network details for various chains.
    constructor() {
        // Ethereum
        s_networkDetails[1] = NetworkDetails({
            chainSelector: 5009297550715157269,
            routerAddress: 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D,
            linkAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            wrappedNativeAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            ccipBnMAddress: 0x0AA1e96D2a46Ec6beB2923dE1E61Addf5F5f1dce, // REG address
            ccipLnMAddress: 0x0AA1e96D2a46Ec6beB2923dE1E61Addf5F5f1dce, // REG address
            rmnProxyAddress: 0x411dE17f12D1A34ecC7F45f49844626267c75e81,
            registryModuleOwnerCustomAddress: 0x4855174E9479E211337832E109E7721d43A4CA64,
            tokenAdminRegistryAddress: 0xb22764f98dD05c789929716D677382Df22C05Cb6
        });

        // Gnosis
        s_networkDetails[100] = NetworkDetails({
            chainSelector: 465200170687744372,
            routerAddress: 0x4aAD6071085df840abD9Baf1697d5D5992bDadce,
            linkAddress: 0xE2e73A1c69ecF83F464EFCE6A5be353a37cA09b2,
            wrappedNativeAddress: 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d,
            ccipBnMAddress: 0x0AA1e96D2a46Ec6beB2923dE1E61Addf5F5f1dce, // REG address
            ccipLnMAddress: 0x0AA1e96D2a46Ec6beB2923dE1E61Addf5F5f1dce, // REG address
            rmnProxyAddress: 0xf5e5e1676942520995c1e39aFaC58A75Fe1cd2bB,
            registryModuleOwnerCustomAddress: 0x1f524a11d89D68a4E4b1c8A195E91Fb1d8f0B56a,
            tokenAdminRegistryAddress: 0x73BC11423CBF14914998C23B0aFC9BE0cb5B2229
        });

        // Polygon
        s_networkDetails[137] = NetworkDetails({
            chainSelector: 4051577828743386545,
            routerAddress: 0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe,
            linkAddress: 0xb0897686c545045aFc77CF20eC7A532E3120E0F1,
            wrappedNativeAddress: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270,
            ccipBnMAddress: 0x0AA1e96D2a46Ec6beB2923dE1E61Addf5F5f1dce, // REG address
            ccipLnMAddress: 0x0AA1e96D2a46Ec6beB2923dE1E61Addf5F5f1dce, // REG address
            rmnProxyAddress: 0xf1ceAa46D8d13Cac9fC38aaEF3d3d14754C5A9c2,
            registryModuleOwnerCustomAddress: 0xc751E86208F0F8aF2d5CD0e29716cA7AD98B5eF5,
            tokenAdminRegistryAddress: 0x00F027eA6D0fb03256A15E9182B2B9227A4931d8
        });

        // // Arbitrum Sepolia
        // s_networkDetails[421614] = NetworkDetails({
        //     chainSelector: 3478487238524512106,
        //     routerAddress: 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165,
        //     linkAddress: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
        //     wrappedNativeAddress: 0xE591bf0A0CF924A0674d7792db046B23CEbF5f34,
        //     ccipBnMAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
        //     ccipLnMAddress: 0x139E99f0ab4084E14e6bb7DacA289a91a2d92927,
        //     rmnProxyAddress: 0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2,
        //     registryModuleOwnerCustomAddress: 0xE625f0b8b0Ac86946035a7729Aba124c8A64cf69,
        //     tokenAdminRegistryAddress: 0x8126bE56454B628a88C17849B9ED99dd5a11Bd2f
        // });

        // // Base Sepolia
        // s_networkDetails[84532] = NetworkDetails({
        //     chainSelector: 10344971235874465080,
        //     routerAddress: 0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93,
        //     linkAddress: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
        //     wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
        //     ccipBnMAddress: 0x88A2d74F47a237a62e7A51cdDa67270CE381555e,
        //     ccipLnMAddress: 0xA98FA8A008371b9408195e52734b1768c0d1Cb5c,
        //     rmnProxyAddress: 0x99360767a4705f68CcCb9533195B761648d6d807,
        //     registryModuleOwnerCustomAddress: 0x8A55C61227f26a3e2f217842eCF20b52007bAaBe,
        //     tokenAdminRegistryAddress: 0x736D0bBb318c1B27Ff686cd19804094E66250e17
        // });

        // // Blast Sepolia
        // s_networkDetails[168587773] = NetworkDetails({
        //     chainSelector: 2027362563942762617,
        //     routerAddress: 0xfb2f2A207dC428da81fbAFfDDe121761f8Be1194,
        //     linkAddress: 0x02c359ebf98fc8BF793F970F9B8302bb373BdF32,
        //     wrappedNativeAddress: 0x4200000000000000000000000000000000000023,
        //     ccipBnMAddress: 0x8D122C3e8ce9C8B62b87d3551bDfD8C259Bb0771,
        //     ccipLnMAddress: 0x35347A2fC1f2a4c5Eae03339040d0b83b09e6FDA,
        //     rmnProxyAddress: 0x1cb6afB6F411f0469c3C0d5D46f6e8f7fd3eADe0,
        //     registryModuleOwnerCustomAddress: 0x912F59E92467C54BBab49ED3a5d431504aFBa30c,
        //     tokenAdminRegistryAddress: 0x98f1703B9C02f9Ab8bA4cc209Ee8D7B188Bb43a8
        // });

        // // BNB Chain Testnet
        // s_networkDetails[97] = NetworkDetails({
        //     chainSelector: 13264668187771770619,
        //     routerAddress: 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f,
        //     linkAddress: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06,
        //     wrappedNativeAddress: 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd,
        //     ccipBnMAddress: 0xbFA2ACd33ED6EEc0ed3Cc06bF1ac38d22b36B9e9,
        //     ccipLnMAddress: 0x79a4Fc27f69323660f5Bfc12dEe21c3cC14f5901,
        //     rmnProxyAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
        //     registryModuleOwnerCustomAddress: 0x763685240370758c5ac6C5F7c22AB36684c0570E,
        //     tokenAdminRegistryAddress: 0xF8f2A4466039Ac8adf9944fD67DBb3bb13888f2B
        // });

        // // Celo Testnet Alfajores
        // s_networkDetails[44787] = NetworkDetails({
        //     chainSelector: 3552045678561919002,
        //     routerAddress: 0xb00E95b773528E2Ea724DB06B75113F239D15Dca,
        //     linkAddress: 0x32E08557B14FaD8908025619797221281D439071,
        //     wrappedNativeAddress: 0x99604d0e2EfE7ABFb58BdE565b5330Bb46Ab3Dca,
        //     ccipBnMAddress: 0x7e503dd1dAF90117A1b79953321043d9E6815C72,
        //     ccipLnMAddress: 0x7F4e739D40E58BBd59dAD388171d18e37B26326f,
        //     rmnProxyAddress: 0x7A394C616A7347dc91C40159929e1c9a435cb83A,
        //     registryModuleOwnerCustomAddress: 0xa8c380Ecd336401Ee896Df33b93F1c76b749C902,
        //     tokenAdminRegistryAddress: 0x5585040bED214fdC60c9cE8c3E8a9c52CE19f4Ea
        // });

        // // Avalanche Fuji
        // s_networkDetails[43113] = NetworkDetails({
        //     chainSelector: 14767482510784806043,
        //     routerAddress: 0xF694E193200268f9a4868e4Aa017A0118C9a8177,
        //     linkAddress: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
        //     wrappedNativeAddress: 0xd00ae08403B9bbb9124bB305C09058E32C39A48c,
        //     ccipBnMAddress: 0xD21341536c5cF5EB1bcb58f6723cE26e8D8E90e4,
        //     ccipLnMAddress: 0x70F5c5C40b873EA597776DA2C21929A8282A3b35,
        //     rmnProxyAddress: 0xAc8CFc3762a979628334a0E4C1026244498E821b,
        //     registryModuleOwnerCustomAddress: 0x97300785aF1edE1343DB6d90706A35CF14aA3d81,
        //     tokenAdminRegistryAddress: 0xA92053a4a3922084d992fD2835bdBa4caC6877e6
        // });

        // // Kroma Sepolia
        // s_networkDetails[2358] = NetworkDetails({
        //     chainSelector: 5990477251245693094,
        //     routerAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
        //     linkAddress: 0xa75cCA5b404ec6F4BB6EC4853D177FE7057085c8,
        //     wrappedNativeAddress: 0x4200000000000000000000000000000000000001,
        //     ccipBnMAddress: 0x6AC3e353D1DDda24d5A5416024d6E436b8817A4e,
        //     ccipLnMAddress: 0x835fcBB6770E1246CfCf52F83cDcec3177d0bb6b,
        //     rmnProxyAddress: 0xA930c1E0fF1E1005E8Ef569Aa81e6EEbf466b1c3,
        //     registryModuleOwnerCustomAddress: 0x683995A22b3654556E9EeA29C0b9df973be6D549,
        //     tokenAdminRegistryAddress: 0xaE669d8217c00b02Fb7a7d9902c897745F4f4c83
        // });

        // // Metis Sepolia
        // s_networkDetails[59902] = NetworkDetails({
        //     chainSelector: 3777822886988675105,
        //     routerAddress: 0xaCdaBa07ECad81dc634458b98673931DD9d3Bc14,
        //     linkAddress: 0x9870D6a0e05F867EAAe696e106741843F7fD116D,
        //     wrappedNativeAddress: 0x5c48e07062aC4E2Cf4b9A768a711Aef18e8fbdA0,
        //     ccipBnMAddress: 0x20Aa09AAb761e2E600d65c6929A9fd1E59821D3f,
        //     ccipLnMAddress: 0x705b364CadE0e515577F2646529e3A417473a155,
        //     rmnProxyAddress: 0xfd66EBE7335E91ae6f4CCCccdDDF262Ab5e35c71,
        //     registryModuleOwnerCustomAddress: 0xA8942fF01DE753BDa1D39acA8774f0872Eee5080,
        //     tokenAdminRegistryAddress: 0x31668C3E8f96415286e9e03592ad97E50e565f52
        // });

        // // Mode Sepolia
        // s_networkDetails[919] = NetworkDetails({
        //     chainSelector: 829525985033418733,
        //     routerAddress: 0xc49ec0eB4beb48B8Da4cceC51AA9A5bD0D0A4c43,
        //     linkAddress: 0x925a4bfE64AE2bFAC8a02b35F78e60C29743755d,
        //     wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
        //     ccipBnMAddress: 0xB9d4e1141E67ECFedC8A8139b5229b7FF2BF16F5,
        //     ccipLnMAddress: 0x86f9Eed8EAD1534D87d23FbAB247D764fC725D49,
        //     rmnProxyAddress: 0xcbFD5e55619B4EE3E6e7fe3CEb0E78fDf7d82dfc,
        //     registryModuleOwnerCustomAddress: 0x4f4fe77A9dBEDe8c4EbFe51932C2E08A37c890ED,
        //     tokenAdminRegistryAddress: 0xc89d4ff0cb206677a7555e52500879bfab73cC68
        // });

        // // Optimism Sepolia
        // s_networkDetails[11155420] = NetworkDetails({
        //     chainSelector: 5224473277236331295,
        //     routerAddress: 0x114A20A10b43D4115e5aeef7345a1A71d2a60C57,
        //     linkAddress: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
        //     wrappedNativeAddress: 0x4200000000000000000000000000000000000006,
        //     ccipBnMAddress: 0x8aF4204e30565DF93352fE8E1De78925F6664dA7,
        //     ccipLnMAddress: 0x044a6B4b561af69D2319A2f4be5Ec327a6975D0a,
        //     rmnProxyAddress: 0xb40A3109075965cc09E93719e33E748abf680dAe,
        //     registryModuleOwnerCustomAddress: 0x49c4ba01dc6F5090f9df43Ab8F79449Db91A0CBB,
        //     tokenAdminRegistryAddress: 0x1d702b1FA12F347f0921C722f9D9166F00DEB67A
        // });

        // // WEMIX Testnet
        // s_networkDetails[1112] = NetworkDetails({
        //     chainSelector: 9284632837123596123,
        //     routerAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
        //     linkAddress: 0x3580c7A817cCD41f7e02143BFa411D4EeAE78093,
        //     wrappedNativeAddress: 0xbE3686643c05f00eC46e73da594c78098F7a9Ae7,
        //     ccipBnMAddress: 0xF4E4057FbBc86915F4b2d63EEFFe641C03294ffc,
        //     ccipLnMAddress: 0xcb342aE3D65E3fEDF8F912B0432e2B8F88514d5D,
        //     rmnProxyAddress: 0xA930c1E0fF1E1005E8Ef569Aa81e6EEbf466b1c3,
        //     registryModuleOwnerCustomAddress: 0x7050BD352A5Aacf774CF883f9345a0C10BdF3cD2,
        //     tokenAdminRegistryAddress: 0xecf484BFcC51F24fcB31056c262A021bAf688D9B
        // });

        // // zkSync Sepolia
        // s_networkDetails[300] = NetworkDetails({
        //     chainSelector: 6898391096552792247,
        //     routerAddress: 0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16,
        //     linkAddress: 0x23A1aFD896c8c8876AF46aDc38521f4432658d1e,
        //     wrappedNativeAddress: 0x4317b2eCD41851173175005783322D29E9bAee9E,
        //     ccipBnMAddress: 0xFf6d0c1518A8104611f482eb2801CaF4f13c9dEb,
        //     ccipLnMAddress: 0xBf8eA19505ab7Eb266aeD435B11bd56321BFB5c5,
        //     rmnProxyAddress: 0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467,
        //     registryModuleOwnerCustomAddress: 0x3139687Ee9938422F57933C3CDB3E21EE43c4d0F,
        //     tokenAdminRegistryAddress: 0xc7777f12258014866c677Bdb679D0b007405b7DF
        // });
    }

    /**
     * @notice Retrieves network details for a given chain ID.
     *
     * @param chainId - The ID of the chain to get the details for.
     * @return networkDetails - The network details for the specified chain ID.
     */
    function getNetworkDetails(
        uint256 chainId
    ) external view returns (NetworkDetails memory networkDetails) {
        networkDetails = s_networkDetails[chainId];
    }

    /**
     * @notice Sets the network details for a given chain ID.
     *
     * @param chainId - The ID of the chain to set the details for.
     * @param networkDetails - The network details to set for the specified chain ID.
     */
    function setNetworkDetails(
        uint256 chainId,
        NetworkDetails memory networkDetails
    ) external {
        s_networkDetails[chainId] = networkDetails;
    }
}
