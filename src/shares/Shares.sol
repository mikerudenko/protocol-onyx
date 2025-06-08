// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Foundation <foundation@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IFeeHandler} from "src/interfaces/IFeeHandler.sol";
import {IValuationHandler} from "src/interfaces/IValuationHandler.sol";
import {StorageHelpersLib} from "src/utils/StorageHelpersLib.sol";

/// @title Shares Contract
/// @author Enzyme Foundation <security@enzyme.finance>
/// @notice Shares token with issuance-related logic
/// @dev Security notes:
/// - there are no built-in protections against:
///   - a very low totalSupply() (e.g., "inflation attack")
///   - a very low share value
contract Shares is ERC20Upgradeable, Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    //==================================================================================================================
    // Types
    //==================================================================================================================

    enum HolderRestriction {
        None,
        RestrictedNoTransfers,
        RestrictedWithTransfers
    }

    //==================================================================================================================
    // Storage
    //==================================================================================================================

    bytes32 private immutable SHARES_STORAGE_LOCATION = StorageHelpersLib.deriveErc7201Location("Shares");

    /// @custom:storage-location erc7201:enzyme.Shares
    struct SharesStorage {
        bytes32 valueAsset;
        address depositAssetsDest;
        HolderRestriction holderRestriction; // packed with `depositAssetsDest` since they are called together during deposits
        address redeemAssetsSrc;
        address feeAssetsSrc;
        address feeHandler;
        address valuationHandler;
        mapping(address => bool) isDepositHandler;
        mapping(address => bool) isRedeemHandler;
        mapping(address => bool) isAdmin;
        mapping(address => bool) isAllowedHolder;
    }

    function __getSharesStorage() private view returns (SharesStorage storage $) {
        bytes32 location = SHARES_STORAGE_LOCATION;
        assembly {
            $.slot := location
        }
    }

    //==================================================================================================================
    // Events
    //==================================================================================================================

    event AdminAdded(address admin);

    event AdminRemoved(address admin);

    event AllowedHolderAdded(address holder);

    event AllowedHolderRemoved(address holder);

    event DepositAssetsDestSet(address dest);

    event DepositHandlerAdded(address depositHandler);

    event DepositHandlerRemoved(address depositHandler);

    event RedeemAssetsSrcSet(address src);

    event FeeAssetsSrcSet(address src);

    event FeeHandlerSet(address feeHandler);

    event HolderRestrictionSet(HolderRestriction holderRestriction);

    event RedeemHandlerAdded(address redeemHandler);

    event RedeemHandlerRemoved(address redeemHandler);

    event ValuationHandlerSet(address valuationHandler);

    event ValueAssetSet(bytes32 valueAsset);

    //==================================================================================================================
    // Errors
    //==================================================================================================================

    error Shares__AddAdmin__AlreadyAdded();

    error Shares__AddAllowedHolder__AlreadyAdded();

    error Shares__AddDepositHandler__AlreadyAdded();

    error Shares__AddRedeemHandler__AlreadyAdded();

    error Shares__AuthTransfer__Unauthorized();

    error Shares__GetDepositAssetsDest__NotSet();

    error Shares__Init__EmptyName();

    error Shares__Init__EmptySymbol();

    error Shares__OnlyAdminOrOwner__Unauthorized();

    error Shares__OnlyDepositHandler__Unauthorized();

    error Shares__OnlyFeeHandler__Unauthorized();

    error Shares__OnlyRedeemHandler__Unauthorized();

    error Shares__RemoveAdmin__AlreadyRemoved();

    error Shares__RemoveAllowedHolder__AlreadyRemoved();

    error Shares__RemoveDepositHandler__AlreadyRemoved();

    error Shares__RemoveRedeemHandler__AlreadyRemoved();

    error Shares__SetValueAsset__Empty();

    error Shares__ValidateTransferRecipient__NotAllowed();

    //==================================================================================================================
    // Modifiers
    //==================================================================================================================

    modifier onlyAdminOrOwner() {
        require(isAdminOrOwner(msg.sender), Shares__OnlyAdminOrOwner__Unauthorized());

        _;
    }

    modifier onlyDepositHandler() {
        require(isDepositHandler(msg.sender), Shares__OnlyDepositHandler__Unauthorized());

        _;
    }

    modifier onlyFeeHandler() {
        require(msg.sender == getFeeHandler(), Shares__OnlyFeeHandler__Unauthorized());

        _;
    }

    modifier onlyRedeemHandler() {
        require(isRedeemHandler(msg.sender), Shares__OnlyRedeemHandler__Unauthorized());

        _;
    }

    //==================================================================================================================
    // Initialize
    //==================================================================================================================

    function init(address _owner, string memory _name, string memory _symbol, bytes32 _valueAsset)
        external
        initializer
    {
        require(bytes(_name).length > 0, Shares__Init__EmptyName());
        require(bytes(_symbol).length > 0, Shares__Init__EmptySymbol());

        __ERC20_init({name_: _name, symbol_: _symbol});
        __Ownable_init({initialOwner: _owner});

        __setValueAsset(_valueAsset);
    }

    //==================================================================================================================
    // ERC20 overrides
    //==================================================================================================================

    /// @dev ERC20 override: validate recipient
    function transfer(address _to, uint256 _value) public override returns (bool) {
        __validateTransferRecipient({_who: _to});

        return super.transfer(_to, _value);
    }

    /// @dev ERC20 override: validate recipient
    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        __validateTransferRecipient({_who: _to});

        return super.transferFrom(_from, _to, _value);
    }

    //==================================================================================================================
    // ERC20-like extensions (access: mixed)
    //==================================================================================================================

    /// @dev Allows unvalidated transfer of shares from trusted handlers.
    /// Any validation of the recipient must be done by the calling contract.
    function authTransfer(address _to, uint256 _amount) external {
        require(isDepositHandler(msg.sender) || isRedeemHandler(msg.sender), Shares__AuthTransfer__Unauthorized());

        _transfer(msg.sender, _to, _amount);
    }

    /// @dev Sometimes a compliance requirement, and simpler than using both deposit+redeem handler permissions.
    /// Not subject to transfer rules.
    function forceTransferFrom(address _from, address _to, uint256 _amount) external onlyAdminOrOwner {
        _transfer(_from, _to, _amount);
    }

    //==================================================================================================================
    // Config (access: owner)
    //==================================================================================================================

    function addAdmin(address _admin) external onlyOwner {
        require(!isAdmin(_admin), Shares__AddAdmin__AlreadyAdded());

        SharesStorage storage $ = __getSharesStorage();
        $.isAdmin[_admin] = true;

        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(isAdmin(_admin), Shares__RemoveAdmin__AlreadyRemoved());

        SharesStorage storage $ = __getSharesStorage();
        $.isAdmin[_admin] = false;

        emit AdminRemoved(_admin);
    }

    //==================================================================================================================
    // Config (access: admin or owner)
    //==================================================================================================================

    // ASSET SOURCES AND DESTINATIONS

    function setDepositAssetsDest(address _depositAssetsDest) external onlyAdminOrOwner {
        SharesStorage storage $ = __getSharesStorage();
        $.depositAssetsDest = _depositAssetsDest;

        emit DepositAssetsDestSet(_depositAssetsDest);
    }

    function setFeeAssetsSrc(address _feeAssetsSrc) external onlyAdminOrOwner {
        SharesStorage storage $ = __getSharesStorage();
        $.feeAssetsSrc = _feeAssetsSrc;

        emit FeeAssetsSrcSet(_feeAssetsSrc);
    }

    function setRedeemAssetsSrc(address _redeemAssetsSrc) external onlyAdminOrOwner {
        SharesStorage storage $ = __getSharesStorage();
        $.redeemAssetsSrc = _redeemAssetsSrc;

        emit RedeemAssetsSrcSet(_redeemAssetsSrc);
    }

    // SYSTEM CONTRACTS

    function addDepositHandler(address _handler) external onlyAdminOrOwner {
        require(!isDepositHandler(_handler), Shares__AddDepositHandler__AlreadyAdded());

        SharesStorage storage $ = __getSharesStorage();
        $.isDepositHandler[_handler] = true;

        emit DepositHandlerAdded(_handler);
    }

    function addRedeemHandler(address _handler) external onlyAdminOrOwner {
        require(!isRedeemHandler(_handler), Shares__AddRedeemHandler__AlreadyAdded());

        SharesStorage storage $ = __getSharesStorage();
        $.isRedeemHandler[_handler] = true;

        emit RedeemHandlerAdded(_handler);
    }

    function removeDepositHandler(address _handler) external onlyAdminOrOwner {
        require(isDepositHandler(_handler), Shares__RemoveDepositHandler__AlreadyRemoved());

        SharesStorage storage $ = __getSharesStorage();
        $.isDepositHandler[_handler] = false;

        emit DepositHandlerRemoved(_handler);
    }

    function removeRedeemHandler(address _handler) external onlyAdminOrOwner {
        require(isRedeemHandler(_handler), Shares__RemoveRedeemHandler__AlreadyRemoved());

        SharesStorage storage $ = __getSharesStorage();
        $.isRedeemHandler[_handler] = false;

        emit RedeemHandlerRemoved(_handler);
    }

    function setFeeHandler(address _feeHandler) external onlyAdminOrOwner {
        SharesStorage storage $ = __getSharesStorage();
        $.feeHandler = _feeHandler;

        emit FeeHandlerSet(_feeHandler);
    }

    function setValuationHandler(address _valuationHandler) external onlyAdminOrOwner {
        SharesStorage storage $ = __getSharesStorage();
        $.valuationHandler = _valuationHandler;

        emit ValuationHandlerSet(_valuationHandler);
    }

    // SHARES HOLDING

    function addAllowedHolder(address _holder) external onlyAdminOrOwner {
        require(!isAllowedHolder(_holder), Shares__AddAllowedHolder__AlreadyAdded());

        SharesStorage storage $ = __getSharesStorage();
        $.isAllowedHolder[_holder] = true;

        emit AllowedHolderAdded(_holder);
    }

    function removeAllowedHolder(address _holder) external onlyAdminOrOwner {
        require(isAllowedHolder(_holder), Shares__RemoveAllowedHolder__AlreadyRemoved());

        SharesStorage storage $ = __getSharesStorage();
        $.isAllowedHolder[_holder] = false;

        emit AllowedHolderRemoved(_holder);
    }

    function setHolderRestriction(HolderRestriction _holderRestriction) external onlyAdminOrOwner {
        SharesStorage storage $ = __getSharesStorage();
        $.holderRestriction = _holderRestriction;

        emit HolderRestrictionSet(_holderRestriction);
    }

    // HELPERS

    function __setValueAsset(bytes32 _valueAsset) internal {
        require(_valueAsset != "", Shares__SetValueAsset__Empty());

        SharesStorage storage $ = __getSharesStorage();
        $.valueAsset = _valueAsset;

        emit ValueAssetSet(_valueAsset);
    }

    //==================================================================================================================
    // Valuation
    //==================================================================================================================

    function sharePrice() external view returns (uint256 price_, uint256 timestamp_) {
        return IValuationHandler(getValuationHandler()).getSharePrice();
    }

    function shareValue() external view returns (uint256 value_, uint256 timestamp_) {
        return IValuationHandler(getValuationHandler()).getShareValue();
    }

    //==================================================================================================================
    // Shares issuance and asset transfers
    //==================================================================================================================

    /// @dev Any shares flows within deposit and redeem handlers must be validated within those individual contracts,
    /// e.g., with calls to isAllowedDepositRecipient() or isAllowedTransferRecipient()

    /// @dev No general burn() function is exposed, in order to guarantee constant supply during share value updates

    // DEPOSIT FLOW

    /// @dev Callable by: DepositHandler
    function mintFor(address _to, uint256 _sharesAmount) external onlyDepositHandler {
        _mint(_to, _sharesAmount);
    }

    // REDEEM FLOW

    /// @dev Callable by: RedeemHandler
    function burnFor(address _from, uint256 _sharesAmount) external onlyRedeemHandler {
        _burn(_from, _sharesAmount);
    }

    /// @dev Callable by: RedeemHandler
    function withdrawRedeemAssetTo(address _asset, address _to, uint256 _amount) external onlyRedeemHandler {
        IERC20(_asset).safeTransferFrom(getRedeemAssetsSrc(), _to, _amount);
    }

    // FEES FLOW

    /// @dev Callable by: FeeHandler
    function withdrawFeeAssetTo(address _asset, address _to, uint256 _amount) external onlyFeeHandler {
        IERC20(_asset).safeTransferFrom(getFeeAssetsSrc(), _to, _amount);
    }

    // ALLOWED DEPOSIT AND TRANSFER RECIPIENTS

    /// @dev Allowed if:
    /// A. holders are unrestricted
    /// B. user has been added as an allowed holder
    function isAllowedDepositRecipient(address _who) public view returns (bool) {
        return getHolderRestriction() == HolderRestriction.None || isAllowedHolder(_who);
    }

    /// @dev Allowed if:
    /// A. holders are unrestricted
    /// B. recipient is an authorized redeem handler (i.e., for async shares requests)
    /// C. transfer between allowed holders is permitted + recipient is an allowed holder
    function isAllowedTransferRecipient(address _who) public view returns (bool) {
        return getHolderRestriction() == HolderRestriction.None || isRedeemHandler(_who)
            || (getHolderRestriction() == HolderRestriction.RestrictedWithTransfers && isAllowedHolder(_who));
    }

    function __validateTransferRecipient(address _who) internal view {
        require(isAllowedTransferRecipient(_who), Shares__ValidateTransferRecipient__NotAllowed());
    }

    //==================================================================================================================
    // Misc
    //==================================================================================================================

    function isAdminOrOwner(address _who) public view returns (bool) {
        return _who == owner() || isAdmin(_who);
    }

    //==================================================================================================================
    // State getters
    //==================================================================================================================

    /// @dev Non-standard to have getter revert, but prevents sending to address(0)
    function getDepositAssetsDest() public view returns (address) {
        address depositAssetsDest = __getSharesStorage().depositAssetsDest;
        require(depositAssetsDest != address(0), Shares__GetDepositAssetsDest__NotSet());

        return __getSharesStorage().depositAssetsDest;
    }

    function getFeeAssetsSrc() public view returns (address) {
        return __getSharesStorage().feeAssetsSrc;
    }

    function getFeeHandler() public view returns (address) {
        return __getSharesStorage().feeHandler;
    }

    function getHolderRestriction() public view returns (HolderRestriction) {
        return __getSharesStorage().holderRestriction;
    }

    function getRedeemAssetsSrc() public view returns (address) {
        return __getSharesStorage().redeemAssetsSrc;
    }

    function getValuationHandler() public view returns (address) {
        return __getSharesStorage().valuationHandler;
    }

    function getValueAsset() public view returns (bytes32) {
        return __getSharesStorage().valueAsset;
    }

    function isAdmin(address _who) public view returns (bool) {
        return __getSharesStorage().isAdmin[_who];
    }

    function isAllowedHolder(address _who) public view returns (bool) {
        return __getSharesStorage().isAllowedHolder[_who];
    }

    function isDepositHandler(address _who) public view returns (bool) {
        return __getSharesStorage().isDepositHandler[_who];
    }

    function isRedeemHandler(address _who) public view returns (bool) {
        return __getSharesStorage().isRedeemHandler[_who];
    }
}
