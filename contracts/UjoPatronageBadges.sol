pragma solidity ^0.4.21;
import "./eip721/EIP721.sol";
import "./utils/strings.sol";
import "../node_modules/ujo-contracts-oracle/contracts/IUSDETHOracle.sol";


contract UjoPatronageBadges is EIP721 {
    using strings for *;
    // enumeration

    // cid -> beneficiary -> usd -> total
    mapping (string => mapping(address => mapping(uint256 => uint256))) internal totalMintedBadgesPerCombination;

    // token ID -> badge number (derived when it is minted).
    mapping (uint256 => uint256) public badgeNumber;

    // token ID -> what CID it pertains to.
    mapping (uint256 => string) public cidOfBadge;

    // token ID -> what beneficiary it pertains to.
    mapping (uint256 => address) public beneficiaryOfBadge;

    // token ID -> what usd cost it pertains to.
    mapping (uint256 => uint256) public usdCostOfBadge;

    address public admin;

    IUSDETHOracle public oracle;

    function UjoPatronageBadges(address _admin) public {
        admin = _admin; // sets oracle used.
        name = "Patronage Badges";
        symbol = "PATRON";
    }

    function setOracle(address _oracle) public onlyAdmin {
        oracle = IUSDETHOracle(_oracle);
    }

    // additional helper function not in EIP721.
    function getAllTokens(address _owner) public view returns (uint256[]) {
        uint size = ownedTokens[_owner].length;
        uint[] memory result = new uint256[](size);
        for (uint i = 0; i < size; i++) {
            result[i] = ownedTokens[_owner][i];
        }
        return result;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    // cid == any IPFS object
    function mint(string _cid, address _beneficiary, uint256 _usdCost) public payable {
        //price of one wei for calculation purposes
        uint256 exchangeRate = oracle.getUintPrice(); // todo: what if this is broken?
        require(exchangeRate > 0);
        uint usdCostInWei = (1 ether / exchangeRate) * _usdCost;

        require(msg.value >= usdCostInWei);

        // compute badge information & mint it.
        uint256 tokenId = computeID(_cid, _beneficiary, _usdCost, totalMintedBadgesPerCombination[_cid][_beneficiary][_usdCost]);
        badgeNumber[tokenId] = totalMintedBadgesPerCombination[_cid][_beneficiary][_usdCost];
        cidOfBadge[tokenId] = _cid;
        beneficiaryOfBadge[tokenId] = _beneficiary;
        usdCostOfBadge[tokenId] = _usdCost;
        tokenURIs[tokenId] = _cid;
        addToken(msg.sender, tokenId);

        totalMintedBadgesPerCombination[_cid][_beneficiary][_usdCost] += 1;

        //  check if paid enough through oracle price
        //  only type now is: > $5 via oracle. Send back remainder.
        //  forward ETH equivalent to $5.
        //  send back remainder.
        // if less than $5, revert.
        if (msg.value > usdCostInWei) {
            msg.sender.transfer(msg.value - usdCostInWei);
        }

        _beneficiary.transfer(usdCostInWei);
    }

    function computeID(string _cid, address _beneficiary, uint256 _usdCost, uint256 _counter) public returns (uint256) {
        // determine unique uint ID combining the CID with the number per CID.
        // this is to ensure that we also track the number of badges per artist.
        // steps as it unfolds:
        // 1) turn integer counter into a string
        // 2) turn beneficiary address into a string
        // 3) concatenate the cid + beneficiary + counter
        // 4) get a hash of the combination.
        // 5) get integer value of hash.

        // solhint-disable-next-line max-line-length
        return uint256(keccak256(_cid.toSlice().concat(toString(_beneficiary).toSlice()).toSlice().concat(bytes32ToString(bytes32(_usdCost)).toSlice()).toSlice().concat(bytes32ToString(bytes32(_counter)).toSlice()))); // concatenate cid + beneficiary + counter
    }

    function changeAdmin(address _newAdmin) public onlyAdmin {
        admin = _newAdmin;
    }

    // URI is the CID
    // solhint-disable-next-line func-param-name-mixedcase
    function setTokenURI(uint256 _tokenID, string URI) public {
        require(msg.sender == admin);
        tokenURIs[_tokenID] = URI;
    }

    function burnToken(uint256 _tokenId) public {
        require(ownerOfToken[_tokenId] == msg.sender); //token should be in control of owner
        removeToken(msg.sender, _tokenId);
        emit Transfer(msg.sender, 0, _tokenId);
    }

    function getTotalMintedPerCombination(string _cid, address _beneficiary, uint256 _usdCost) public view returns (uint256) {
        return totalMintedBadgesPerCombination[_cid][_beneficiary][_usdCost];
    }

    /*-- internal functions for string CID generation --*/
    function bytes32ToString (bytes32 data) internal returns (string) {
        bytes memory bytesString = new bytes(32);
        for (uint j=0; j < 32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
            }
        }
        return string(bytesString);
    }

    function toString(address x) internal returns (string) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        return string(b);
    }
}
