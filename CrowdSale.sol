pragma solidity^0.4.17;
import './HWD.sol';
import './HWV.sol';


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable{
  address public owner;


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract HWDTokenSale is StandardToken, Ownable {
	using SafeMath for uint256;
	// Events
	event CreatedHWD(address indexed _creator, uint256 _amountOfHWD);
	event CreatedHWV(address indexed _creator, uint256 _amountOfHWV);
	event HWDRefundedForWei(address indexed _refunder, uint256 _amountOfWei);
	event print(uint256 hwd);

	
	// Addresses and contracts
	address public executor;
	//HWD Multisig Wallet
	address public HWDETHDestination=0x8B869ADEe100FC5F561848D0E57E94502Bd9318b;
	//HWD Development activities Wallet
	address public constant devHWDDestination=0x314A3fA55aEa2065bBDd2778bFEd966014ab0081;
	//HWD Core Team reserve Wallet
	address public constant coreHWDDestination=0x22dA10194b5ac5086bDacb2b0f36D8f0a5971b23;
	//HWD Advisory and Promotions (PR/Marketing/Media etcc.) wallet
	address public constant advisoryHWDDestination=0xA91ABE74a1AC3d903dA479Ca9fede3d0954d430B;
	//HWD User DEvelopment Fund Wallet
	address public constant udfHWDDestination=0xf4307CA73451b80A0BaD1E099fD2B7f0fe38b7e9;
	//HWD Cofounder Wallet
	address public constant cofounderHWDDestination=0x863A2217E80e6C6192f63D3716c0cC7711Fad5b4;
	//HWD Unsold Tokens wallet
	address public constant unsoldHWDDestination=0x507608Aa3377ecDF8AD5cD0f26A21bA848DdF435;
	//Total HWD Sold
	uint256 public totalHWD;
	uint256 public totalHWV;
	
	// Sale data
	bool public saleHasEnded;
	bool public minCapReached;
	bool public preSaleEnded;
	bool public allowRefund;
	mapping (address => uint256) public ETHContributed;
	uint256 public totalETHRaised;
	uint256 public preSaleStartBlock;
	uint256 public preSaleEndBlock;
	uint256 public icoEndBlock;
	
    uint public constant coldStorageYears = 10 years;
    uint public coreTeamUnlockedAt;
    uint public unsoldUnlockedAt;
    uint256 coreTeamShare;
    uint256 cofounderShare;
    uint256 advisoryTeamShare;
    
	// Calculate the HWD to ETH rate for the current time period of the sale
	uint256 curTokenRate = HWD_PER_ETH_BASE_RATE;
	uint256 public constant INITIAL_HWD_TOKEN_SUPPLY =HowestDollar.totalSupply;
	uint256 public constant HWD_TOKEN_SUPPLY_TIER1 =500000;
    uint256 public constant HWD_TOKEN_SUPPLY_TIER2 =1000000;
	uint256 public constant HWD_PORTION =500000;  // Total user deve fund share In percentage
	
	uint256 public constant HWD_PER_ETH_BASE_RATE = 0.5;  // 1 HWD = 2 ETH during normal part of token sale
	uint256 public constant HWD_PER_ETH_PRE_SALE_RATE = 1; // 1 HWD @ 50%  discount in pre sale
	

	
	
	function HWDTokenSale () public payable
	{

	    totalSupply = INITIAL_HWD_TOKEN_SUPPLY;

		//Start Pre-sale approx on the 6th october 8:00 GMT
	    preSaleStartBlock=4340582;
	    //preSaleStartBlock=block.number;
	    preSaleEndBlock = preSaleStartBlock + 37800;  // Equivalent to 14 days later, assuming 32 second blocks
	    icoEndBlock = preSaleEndBlock + 81000;  // Equivalent to 30 days , assuming 32 second blocks
		executor = msg.sender;
		saleHasEnded = false;
		minCapReached = false;
		allowRefund = false;
		totalETHRaised = 0;
		totalHWD=0;

	}

	function () payable public {
		
		//minimum .05 Ether required.
		require(msg.value >= .05 ether);
		// If sale is not active, do not create HWD
		require(!saleHasEnded);
		//Requires block to be >= Pre-Sale start block 
		require(block.number >= preSaleStartBlock);
		//Requires block.number to be less than icoEndBlock number
		require(block.number < icoEndBlock);
		//Has the Pre-Sale ended, after 14 days, Pre-Sale ends.
		if (block.number > preSaleEndBlock){
		    preSaleEnded=true;
		}
		// Do not do anything if the amount of ether sent is 0
		require(msg.value!=0);

		uint256 newEtherBalance = totalETHRaised.add(msg.value);
		//Get the appropriate rate which applies
		getCurrentHWDRate();
		// Calculate the amount of HWD being purchase
		
		uint256 amountOfHWD = msg.value.mul(curTokenRate);
	
        //Accrue HWD tokens
		totalHWD=totalHWD.add(amountOfHWD);
	    // if all tokens sold out , sale ends.
		require(totalHWD<= PRESALE_ICO_PORTION);
		
		// Ensure that the transaction is safe
		uint256 totalSupplySafe = totalSupply.sub(amountOfHWD);
		uint256 balanceSafe = balances[msg.sender].add(amountOfHWD);
		uint256 contributedSafe = ETHContributed[msg.sender].add(msg.value);
		
		// Update individual and total balances
		totalSupply = totalSupplySafe;
		balances[msg.sender] = balanceSafe;

		totalETHRaised = newEtherBalance;
		ETHContributed[msg.sender] = contributedSafe;

		CreatedHWD(msg.sender, amountOfHWD);
	}
	
	function getCurrentHWDRate() internal {
	        //default to the base rate
	        curTokenRate = HWD_PER_ETH_BASE_RATE;

	        //if HWD sold < 100 mill and still in presale, use Pre-Sale rate
	        if ((totalHWD <= HWD_TOKEN_SUPPLY_TIER1) && (!preSaleEnded)) {    
			        curTokenRate = HWD_PER_ETH_PRE_SALE_RATE;
	        }
		    //If HWDHWD Sold < 100 mill and Pre-Sale ended, use Tier2 rate
	        if ((totalHWD <= HWD_TOKEN_SUPPLY_TIER1) && (preSaleEnded)) {
			     curTokenRate = HWD_PER_ETH_ICO_TIER2_RATE;
		    }
		    //if HWDHWDHWD Sold > 100 mill, use Tier 2 rate irrespective of Pre-Sale end or not
		    if (totalHWD >HWD_TOKEN_SUPPLY_TIER1 ) {
			    curTokenRate = HWD_PER_ETH_ICO_TIER2_RATE;
		    }
		    //if HWD sold more than 200 mill use Tier3 rate
		    if (totalHWD >HWD_TOKEN_SUPPLY_TIER2 ) {
			    curTokenRate = HWD_PER_ETH_ICO_TIER3_RATE;
		        
		    }
            //if HWD sod more than 300mill
		    if (totalHWD >HWD_TOKEN_SUPPLY_TIER3){
		        curTokenRate = HWD_PER_ETH_BASE_RATE;
		    }
	}
    // Create HWD tokens from the Advisory bucket for marketing, PR, Media where we are 
    //paying upfront for these activities in HWD tokens.
    //Clients = Media, PR, Marketing promotion etc.
    function createCustomHWD(address _clientHWDAddress,uint256 _value) public onlyOwner {
	    //Check the address is valid
	    require(_clientHWDAddress != address(0x0));
		require(_value >0);
		require(advisoryTeamShare>= _value);
	   
	  	uint256 amountOfHWD = _value;
	  	//Reduce from advisoryTeamShare
	    advisoryTeamShare=advisoryTeamShare.sub(amountOfHWD);
        //Accrue HWDP tokens
		totalHWD=totalHWD.add(amountOfHWD);
		//Assign tokens to the client
		uint256 balanceSafe = balances[_clientHWDAddress].add(amountOfHWD);
		balances[_clientHWDAddress] = balanceSafe;
		//Create HWD Created event
		CreatedHWD(_clientHWDAddress, amountOfHWD);
	
	}
    
	function endICO() public onlyOwner{
		// Do not end an already ended sale
		require(!saleHasEnded);
		// Can't end a sale that hasn't hit its minimum cap
		require(minCapReached);
		
		saleHasEnded = true;

		// Calculate share HWDs
	
	    uint256 HWDShare = HWD_PORTION;
	

		balances[HWDDestination] = HWDShare;
		
        // Locked time of approximately 10 years before team members are able to redeeem tokens.
        uint lockTime = coldStorageYears;
        unsoldUnlockedAt = now.add(lockTime);

		CreatedHWD(HWDDestination, HWDShare);

	}
	function unlock() public onlyOwner{
	   require(saleHasEnded);
      }
       if (now > unsoldUnlockedAt) {
          uint256 unsoldTokens=PRESALE_ICO_PORTION.sub(totalHWD);
          require(unsoldTokens > 0);
          balances[unsoldHWDDestination] = unsoldTokens;
          CreatedHWD(coreHWDDestination, unsoldTokens);
         }
    }

	// Allows HWD to withdraw funds
	function withdrawFunds() public onlyOwner {
		// Disallow withdraw if the minimum hasn't been reached
		require(minCapReached);
		require(this.balance > 0);
		if(this.balance > 0) {
			HWDETHDestination.transfer(this.balance);
		}
	}

	// Signals that the sale has reached its minimum funding goal
	function triggerMinCap() public onlyOwner {
		minCapReached = true;
	}

	// Opens refunding.
	function triggerRefund() public onlyOwner{
		// No refunds if the sale was successful
		require(!saleHasEnded);
		// No refunds if minimum cap is hit
		require(!minCapReached);
		// No refunds if the sale is still progressing
	    require(block.number >icoEndBlock);
		require(msg.sender == executor);
		allowRefund = true;
	}

	function claimRefund() external {
		// No refunds until it is approved
		require(allowRefund);
		// Nothing to refund
		require(ETHContributed[msg.sender]!=0);

		// Do the refund.
		uint256 etherAmount = ETHContributed[msg.sender];
		ETHContributed[msg.sender] = 0;

		HWDRefundedForWei(msg.sender, etherAmount);
		msg.sender.transfer(etherAmount);
	}
    //Allow changing the HWD MultiSig wallet incase of emergency
	function changeHWDETHDestinationAddress(address _newAddress) public onlyOwner {
		HWDETHDestination = _newAddress;
	}
	
	function transfer(address _to, uint _value) public returns (bool) {
		// Cannot transfer unless the minimum cap is hit
		require(minCapReached);
		return super.transfer(_to, _value);
	}
	
	function transferFrom(address _from, address _to, uint _value) public returns (bool) {
		// Cannot transfer unless the minimum cap is hit
		require(minCapReached);
		return super.transferFrom(_from, _to, _value);
	}

	
}